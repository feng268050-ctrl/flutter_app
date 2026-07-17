import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lws_hmi/platform/audio/media_audio_controller.dart';
import 'package:lws_hmi/platform/board_helper.dart';
import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/percent.dart';

/// Linux media: ALSA mixer volume (primary) + mpg123 remote for decode.
///
/// OS-style rules:
/// - Volume is a **mixer** property, never tied to restarting the decoder.
/// - Playback state comes from the player (`@P` / process exit), not UI guesses.
/// - Concurrent volume requests coalesce to the **latest** percent (no queue).
/// - Persist + HW mixer apply go through `change-volume`.
class LinuxMediaAudioController implements MediaAudioController {
  LinuxMediaAudioController({
    this.cacheDir = '/var/lib/hmi/audio',
    this.volumePreferencePath = '/var/lib/hmi/media-volume',
    this.changeVolumeCommand = const <String>['change-volume'],
    this.playerBinary = 'mpg123',
    this.amixerBinary = 'amixer',
    BoardHelperRunner? runHelper,
  }) : runHelper = runHelper ?? defaultBoardHelperRunner;

  final String cacheDir;
  final String volumePreferencePath;
  final List<String> changeVolumeCommand;
  final String playerBinary;
  final String amixerBinary;
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

  static const _playbackPathControl = 'Playback Path';
  static const _playbackPathValue = 'RING_SPK_HP';

  static const _preferredVolumeControls = <String>[
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
    if (changeVolumeCommand.isEmpty) {
      debugPrint('media-audio: change-volume skipped (empty command)');
      return;
    }
    final exe = changeVolumeCommand.first;
    final args = <String>[
      ...changeVolumeCommand.sublist(1),
      '$percent',
    ];
    final code = await runHelper(exe, args);
    if (code != 0) {
      debugPrint('media-audio: change-volume exit $code');
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
        _playerStdin!.writeln('V $_volumePercent');
        await _playerStdin!.flush();
        // @P 2 will confirm; optimistically mark playing for responsive UI.
        _setPlaying(true);
      } else {
        await stop();
        _player = await Process.start(player, <String>[path]);
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

  Future<void> _startRemoteMpg123(String player) async {
    // Do not use -q: we need @P status lines for accurate play/stop state.
    _player = await Process.start(player, <String>['-R']);
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
      sink.writeln('V $percent');
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
  Future<void> stop() async {
    final p = _player;
    final sink = _playerStdin;
    if (p == null) {
      _setPlaying(false);
      return;
    }
    try {
      if (sink != null && _remoteMode) {
        // STOP keeps the remote session for the next LOAD (OS decoder lifecycle).
        sink.writeln('STOP');
        await sink.flush();
        _setPlaying(false);
        return;
      }
    } catch (_) {}

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
      p.kill(ProcessSignal.sigterm);
    } catch (e) {
      debugPrint('media-audio: kill failed: $e');
    }
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
    final cached = _extracted[assetKey];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }

    final dir = Directory(cacheDir);
    await dir.create(recursive: true);
    final name = assetKey.split('/').last;
    final out = File('${dir.path}/$name');
    final data = await rootBundle.load(assetKey);
    await out.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    _extracted[assetKey] = out.path;
    return out.path;
  }

  Future<void> _ensurePlaybackPath() async {
    if (_pathRouted) {
      return;
    }
    try {
      final result = await Process.run(
        amixerBinary,
        <String>['sset', _playbackPathControl, _playbackPathValue],
      );
      if (result.exitCode == 0) {
        _pathRouted = true;
        lwsTrace(
          'media-audio: amixer "$_playbackPathControl" → $_playbackPathValue',
        );
      } else {
        debugPrint(
          'media-audio: Playback Path set failed '
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
          if (name == null || name == _playbackPathControl) {
            continue;
          }
          final lower = name.toLowerCase();
          if (lower.contains('volume') ||
              lower == 'master' ||
              lower == 'pcm' ||
              lower == 'speaker' ||
              lower == 'playback') {
            fromDevice.add(name);
          }
        }
      }
    } catch (_) {}

    final ordered = <String>[
      ..._preferredVolumeControls,
      ...fromDevice.where((n) => !_preferredVolumeControls.contains(n)),
    ];
    _discoveredVolumeControls = ordered;
    return ordered;
  }

  Future<void> _applyMixerVolume(int percent) async {
    if (_mixerUnavailable) {
      return;
    }
    if (_volumeControl != null) {
      if (await _ssetVolume(_volumeControl!, percent)) {
        return;
      }
      _volumeControl = null;
    }

    for (final control in await _volumeControlCandidates()) {
      if (await _ssetVolume(control, percent)) {
        _volumeControl = control;
        lwsTrace('media-audio: volume control → $control @ $percent%');
        return;
      }
    }
    _mixerUnavailable = true;
    debugPrint('media-audio: no HW volume control; remote V only');
  }

  Future<bool> _ssetVolume(String control, int percent) async {
    final attempts = <List<String>>[
      <String>['sset', control, '$percent%'],
      <String>['sset', control, '$percent%,$percent%'],
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
    try {
      final r = await Process.run(
        '/usr/libexec/bluetooth/bt-a2dp-volume.sh',
        <String>['$percent'],
      );
      if (r.exitCode != 0) {
        lwsTrace('media-audio: bt-a2dp-volume exit ${r.exitCode}');
      }
    } catch (e) {
      lwsTrace('media-audio: bt-a2dp-volume soft-fail: $e');
    }
  }
}
