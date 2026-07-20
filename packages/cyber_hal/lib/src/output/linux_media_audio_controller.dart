import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/output/volume.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/linux/percent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Linux media: ALSA mixer volume (primary) + mpg123 remote for decode.
///
/// OS-style rules:
/// - Volume is a **mixer** property, never tied to restarting the decoder.
/// - Playback state comes from the player (`@P` / process exit), not UI guesses.
/// - Concurrent volume requests coalesce to the **latest** percent (no queue).
/// - Persist + HW mixer apply go through `change-volume`.
class LinuxMediaAudioController implements MediaAudioController, Volume {
  LinuxMediaAudioController({
    this.cacheDir = '/var/lib/hmi/audio',
    this.volumePreferencePath = '/var/lib/hmi/media-volume',
    this.changeVolumeCommand = const <String>[],
    this.playerBinary = 'mpg123',
    this.amixerBinary = 'amixer',
    this.a2dpVolumeCommand = const <String>[],
    List<String>? preferredVolumeControls,
    this.playbackPathControl = '',
    this.playbackPathValue = '',
    this.alsaOutputDevice = '',
    BoardHelperRunner? runHelper,
  })  : preferredVolumeControls =
            preferredVolumeControls ?? _defaultPreferredVolumeControls,
        runHelper = runHelper ?? defaultBoardHelperRunner;

  final String cacheDir;
  final String volumePreferencePath;
  final List<String> changeVolumeCommand;
  final String playerBinary;
  final String amixerBinary;
  final List<String> a2dpVolumeCommand;
  /// BoardProfile-injected ALSA control preference order.
  final List<String> preferredVolumeControls;
  /// Optional Rockchip-style route enum (e.g. `Playback Path` / `RING_SPK_HP`).
  /// Empty → skip amixer path routing (portable default).
  final String playbackPathControl;
  final String playbackPathValue;
  /// Explicit ALSA PCM for mpg123 (`-a`), e.g. `plughw:0,0`. Empty → mpg123 default.
  /// Prefer this when `default` is broken by bluealsa / missing BT sink.
  final String alsaOutputDevice;
  final BoardHelperRunner runHelper;

  Process? _player;
  IOSink? _playerStdin;
  bool _remoteMode = false;
  int _volumePercent = 80;
  bool _volumeLoaded = false;
  bool _playing = false;
  bool _pathRouted = false;
  String? _volumeControl;
  List<String>? _discoveredVolumeControls;
  bool _mixerUnavailable = false;
  final Map<String, String> _extracted = <String, String>{};

  final StreamController<bool> _playingCtrl =
      StreamController<bool>.broadcast();

  /// In-flight volume apply lock (latest-wins coalesce).
  bool _volumeBusy = false;
  int? _queuedVolume;

  static const _defaultPreferredVolumeControls = <String>[
    'DAC',
    'DAC Playback Volume',
    'Speaker Playback Volume',
    'Headphone Playback Volume',
    'Playback Volume',
    'Master Playback Volume',
    'Master',
    'PCM',
    'Speaker',
    'Playback',
  ];

  @override
  bool get isPlaying => _playing;

  @override
  Stream<bool> get playing => _playingCtrl.stream;

  void _setPlaying(bool value) {
    if (_playing == value) {
      return;
    }
    _playing = value;
    if (!_playingCtrl.isClosed) {
      _playingCtrl.add(value);
    }
  }

  @override
  Future<int> getVolumePercent() async {
    await _ensureVolumeLoaded();
    // If restore hit rk809 `DAC 100%` (or no control yet), retry apply so a
    // later UI read / click prime can recover HW gain without restart.
    if (_mixerUnavailable || _volumeControl == null) {
      _queuedVolume = _volumePercent;
      await _drainVolumeQueue();
    }
    return _volumePercent;
  }

  @override
  Future<void> setVolumePercent(int percent) async {
    _volumePercent = clampPercent(percent);
    _volumeLoaded = true;
    await _changeVolumeHelper(_volumePercent);
    _queuedVolume = _volumePercent;
    await _drainVolumeQueue();
  }

  Future<void> _ensureVolumeLoaded() async {
    if (_volumeLoaded) {
      return;
    }
    _volumeLoaded = true;
    try {
      final f = File(volumePreferencePath);
      if (await f.exists()) {
        final raw = (await f.readAsString()).trim();
        final n = int.tryParse(raw);
        if (n != null) {
          _volumePercent = clampPercent(n);
        }
      }
    } catch (e) {
      debugPrint('media-audio: volume load failed: $e');
    }
    // Apply saved (or default) so mixer matches UI after reboot.
    _queuedVolume = _volumePercent;
    await _drainVolumeQueue();
  }

  Future<void> _changeVolumeHelper(int percent) async {
    if (changeVolumeCommand.isNotEmpty) {
      final exe = changeVolumeCommand.first;
      final args = <String>[
        ...changeVolumeCommand.sublist(1),
        '$percent',
      ];
      final code = await runHelper(exe, args);
      if (code != 0) {
        debugPrint('media-audio: change-volume exit $code');
      }
      return;
    }
    // Default: persist preference; mixer apply is via amixer in _drainVolumeQueue.
    try {
      final f = File(volumePreferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString('$percent\n', flush: true);
    } catch (e) {
      debugPrint('media-audio: persist volume failed: $e');
    }
  }

  /// Latest-wins: while a mixer write runs, keep only the newest target.
  Future<void> _drainVolumeQueue() async {
    if (_volumeBusy) {
      return;
    }
    _volumeBusy = true;
    try {
      await _ensurePlaybackPath();
      while (_queuedVolume != null) {
        final v = _queuedVolume!;
        _queuedVolume = null;
        await _applyMixerVolume(v);
        // Soft volume for remote decoder — never restarts playback.
        await _applyRemoteVolume(v);
        // BlueALSA A2DP sink soft-volume (HW mixer alone does not affect BT PCM).
        await _applyA2dpVolume(v);
      }
    } finally {
      _volumeBusy = false;
      if (_queuedVolume != null) {
        unawaited(_drainVolumeQueue());
      }
    }
  }

  @override
  Future<void> playAsset(String assetKey) async {
    await _ensureVolumeLoaded();
    await _ensurePlaybackPath();
    await _applyMixerVolume(_volumePercent);

    final path = await _ensureExtracted(assetKey);
    final player = await _resolvePlayerBinary();
    if (player == null) {
      debugPrint(
        'media-audio: no player binary (need mpg123 or aplay on rootfs)',
      );
      return;
    }

    final useMpg123 = _isMpg123(player);
    try {
      if (useMpg123) {
        if (_player == null || !_remoteMode) {
          await _startRemoteMpg123(player);
        }
        _playerStdin!.writeln('LOAD $path');
        await _playerStdin!.flush();
        await _applyRemoteVolume(_volumePercent);
        // @P 2 will confirm; optimistically mark playing for responsive UI.
        _setPlaying(true);
      } else {
        await stop();
        final args = useMpg123
            ? <String>[..._mpg123Args(remote: false), path]
            : <String>[path];
        _player = await Process.start(player, args);
        _playerStdin = null;
        _remoteMode = false;
        _setPlaying(true);
        unawaited(_listenProcess(_player!));
      }
      lwsTrace(
        'media-audio: play $path via $player remote=$_remoteMode '
        'volume=$_volumePercent% ctrl=${_volumeControl ?? "remote"}',
      );
    } catch (e) {
      _setPlaying(false);
      debugPrint('media-audio: play failed: $e');
    }
  }

  List<String> _mpg123Args({required bool remote}) {
    final args = <String>[];
    final dev = alsaOutputDevice.trim();
    if (dev.isNotEmpty) {
      args.addAll(<String>['-a', dev]);
    }
    if (remote) {
      // Do not use -q: we need @P status lines for accurate play/stop state.
      args.add('-R');
    }
    return args;
  }

  Future<void> _startRemoteMpg123(String player) async {
    _player = await Process.start(player, _mpg123Args(remote: true));
    _playerStdin = _player!.stdin;
    _remoteMode = true;
    unawaited(_listenProcess(_player!));
  }

  bool _isMpg123(String player) {
    final base = player.split('/').last;
    return base == 'mpg123' || base.startsWith('mpg123');
  }

  Future<String?> _resolvePlayerBinary() async {
    for (final candidate in <String>[playerBinary, 'mpg123', 'aplay']) {
      try {
        final r = await Process.run('sh', <String>['-c', 'command -v $candidate']);
        if (r.exitCode == 0) {
          final out = (r.stdout as String).trim();
          if (out.isNotEmpty) {
            return out;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _applyRemoteVolume(int percent) async {
    final sink = _playerStdin;
    if (!_remoteMode || sink == null) {
      return;
    }
    try {
      // When ALSA mixer is bound, it owns loudness — keep decoder at full scale
      // so UI 70% is not attenuated twice (DAC + mpg123 V).
      final v = _volumeControl != null ? 100 : percent;
      sink.writeln('V $v');
      await sink.flush();
    } catch (e) {
      debugPrint('media-audio: remote volume failed: $e');
    }
  }

  Future<void> _listenProcess(Process process) async {
    unawaited(_consumeLines(process.stdout, process, isStderr: false));
    unawaited(_consumeLines(process.stderr, process, isStderr: true));
    final code = await process.exitCode;
    if (identical(_player, process)) {
      _player = null;
      _playerStdin = null;
      _remoteMode = false;
      _setPlaying(false);
      lwsTrace('media-audio: player exited code=$code');
    }
  }

  Future<void> _consumeLines(
    Stream<List<int>> stream,
    Process process, {
    required bool isStderr,
  }) async {
    try {
      await for (final line
          in stream.transform(systemEncoding.decoder).transform(const LineSplitter())) {
        if (!identical(_player, process)) {
          return;
        }
        final t = line.trim();
        if (t.isEmpty) {
          continue;
        }
        // mpg123 remote: @P 0=stopped 1=paused 2=playing
        if (t.startsWith('@P')) {
          final parts = t.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final code = int.tryParse(parts[1]);
            if (code == 2) {
              _setPlaying(true);
            } else if (code == 0 || code == 1) {
              _setPlaying(false);
            }
          }
          continue;
        }
        if (isStderr || t.startsWith('@')) {
          lwsTrace('media-audio: $t');
        }
      }
    } catch (_) {}
  }


  @override
  Future<void> warmClickSession() async {
    await _ensureVolumeLoaded();
    await _ensurePlaybackPath();
    await _applyMixerVolume(_volumePercent);
    final player = await _resolvePlayerBinary();
    if (player == null || !_isMpg123(player)) {
      return;
    }
    if (!_remoteMode || _playerStdin == null || _player == null) {
      await _startRemoteMpg123(player);
    }
    await _applyRemoteVolume(100);
    lwsTrace('media-audio: click session warm');
  }

  @override
  Future<void> playOneShotAsset(String assetKey) async {
    // Fast path: do not re-run amixer on every tap (was ~tens of ms of latency).
    await _ensureVolumeLoaded();
    await _ensurePlaybackPath();

    final path = await _ensureExtracted(assetKey);
    final player = await _resolvePlayerBinary();
    if (player == null) {
      debugPrint('media-audio: oneshot no player binary');
      return;
    }

    try {
      if (!_remoteMode || _playerStdin == null || _player == null) {
        if (!_isMpg123(player)) {
          debugPrint('media-audio: oneshot needs mpg123 for remote LOAD');
          return;
        }
        await _startRemoteMpg123(player);
        await _applyRemoteVolume(100);
      }
      _playerStdin!.writeln('LOAD $path');
      await _playerStdin!.flush();
      lwsTrace('media-audio: oneshot LOAD $path (remote)');
    } catch (e) {
      debugPrint('media-audio: oneshot remote failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    final sink = _playerStdin;
    _setPlaying(false);
    if (sink == null) {
      return;
    }
    // Keep mpg123 -R alive so UI click oneshots can LOAD without fighting
    // exclusive plughw (a second mpg123 process exits 255 / is silent).
    try {
      sink.writeln('STOP');
      await sink.flush();
    } catch (e) {
      debugPrint('media-audio: stop failed: $e');
    }
  }

  @override
  Future<bool> isMuted() async => false;

  @override
  Future<void> setMuted(bool muted) async {
    // ALSA mute control not wired in v1; volume percent remains the API.
  }

  @override
  Future<void> dispose() async {
    final p = _player;
    final sink = _playerStdin;
    _player = null;
    _playerStdin = null;
    _remoteMode = false;
    _setPlaying(false);
    try {
      if (sink != null) {
        sink.writeln('QUIT');
        await sink.flush();
      }
    } catch (_) {}
    try {
      p?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    await _playingCtrl.close();
  }

  Future<String> _ensureExtracted(String assetKey) async {
    final dir = Directory(cacheDir);
    await dir.create(recursive: true);
    final name = assetKey.split('/').last;
    final out = File('${dir.path}/$name');
    final data = await rootBundle.load(assetKey);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // Always refresh from the asset bundle so push-app asset updates are not
    // masked by a stale /var/lib/hmi/audio/*.mp3 cache.
    if (!await out.exists() || await out.length() != bytes.length) {
      await out.writeAsBytes(bytes, flush: true);
    }
    _extracted[assetKey] = out.path;
    return out.path;
  }

  Future<void> _ensurePlaybackPath({bool force = false}) async {
    if (_pathRouted && !force) {
      return;
    }
    final control = playbackPathControl.trim();
    final value = playbackPathValue.trim();
    if (control.isEmpty || value.isEmpty) {
      _pathRouted = true;
      return;
    }
    try {
      final result = await Process.run(
        amixerBinary,
        <String>['sset', control, value],
      );
      if (result.exitCode == 0) {
        _pathRouted = true;
        lwsTrace('media-audio: amixer "$control" → $value');
      } else {
        debugPrint(
          'media-audio: playback path set failed '
          '(exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } catch (e) {
      debugPrint('media-audio: amixer missing or failed: $e');
    }
  }

  Future<List<String>> _volumeControlCandidates() async {
    if (_discoveredVolumeControls != null) {
      return _discoveredVolumeControls!;
    }

    final fromDevice = <String>[];
    try {
      final result = await Process.run(amixerBinary, <String>['scontrols']);
      if (result.exitCode == 0) {
        final re = RegExp(r"Simple mixer control '([^']+)'");
        for (final match in re.allMatches(result.stdout as String)) {
          final name = match.group(1);
          if (name == null ||
              (playbackPathControl.isNotEmpty &&
                  name == playbackPathControl)) {
            continue;
          }
          final lower = name.toLowerCase();
          if (lower.contains('volume') ||
              lower == 'master' ||
              lower == 'pcm' ||
              lower == 'speaker' ||
              lower == 'playback' ||
              lower == 'dac') {
            fromDevice.add(name);
          }
        }
      }
    } catch (_) {}

    final ordered = <String>[
      ...preferredVolumeControls,
      ...fromDevice.where((n) => !preferredVolumeControls.contains(n)),
    ];
    _discoveredVolumeControls = ordered;
    return ordered;
  }

  Future<void> _applyMixerVolume(int percent) async {
    // Re-probe each apply: a prior 100% / missing-control failure must not
    // permanently mute the session after prefs/route become valid.
    if (_volumeControl != null) {
      if (await _ssetVolume(_volumeControl!, percent)) {
        _mixerUnavailable = false;
        return;
      }
      _volumeControl = null;
    }

    for (final control in await _volumeControlCandidates()) {
      if (await _ssetVolume(control, percent)) {
        _volumeControl = control;
        _mixerUnavailable = false;
        lwsTrace('media-audio: volume control → $control @ $percent%');
        return;
      }
    }
    _mixerUnavailable = true;
    debugPrint('media-audio: no HW volume control; remote V only');
  }

  /// rk809 `DAC` rejects `amixer sset … 100%` / raw 255 (`Invalid command!`).
  /// Clamp HW percent to 0–99 so UI 100 still drives near-max gain.
  @visibleForTesting
  static int amixerHwPercent(int percent) {
    final p = percent < 0 ? 0 : percent;
    if (p >= 100) {
      return 99;
    }
    return p;
  }

  Future<bool> _ssetVolume(String control, int percent) async {
    final hw = amixerHwPercent(percent);
    final attempts = <List<String>>[
      <String>['sset', control, '$hw%'],
      <String>['sset', control, '$hw%,$hw%'],
    ];
    for (final args in attempts) {
      try {
        final result = await Process.run(amixerBinary, args);
        if (result.exitCode == 0) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// BlueALSA soft-volume for phone → speaker (ignore failures when BT off).
  Future<void> _applyA2dpVolume(int percent) async {
    if (a2dpVolumeCommand.isEmpty) {
      return;
    }
    try {
      final r = await Process.run(
        a2dpVolumeCommand.first,
        <String>[...a2dpVolumeCommand.sublist(1), '$percent'],
      );
      if (r.exitCode != 0) {
        lwsTrace('media-audio: bt-a2dp-volume exit ${r.exitCode}');
      }
    } catch (e) {
      lwsTrace('media-audio: bt-a2dp-volume soft-fail: $e');
    }
  }
}
