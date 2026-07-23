import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/output/sound/volume.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/linux/percent.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
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
    this.volumePreferencePath = OutputPrefs.soundConf,
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

  /// Armed warn loop file path (remote sticky session + soft-V, same as click).
  /// Non-null = keep playing: on `@P 0` the controller re-LOADs immediately.
  /// mpg123 remote `LOAD` ignores `--loop`. Same-code appear must not clear this.
  String? _loopPath;

  /// Bumped on [stop] so an in-flight `@P 0` re-LOAD cannot resurrect playback.
  int _warnLoopEpoch = 0;

  /// Seek to frame zero shortly before EOF so ALSA never drains while looping.
  ///
  /// Four MP3 frames are about 104 ms at 44.1 kHz. The bundled warn clip fades
  /// at the tail, so this small overlap is inaudible and avoids the much larger
  /// EOF → Dart callback → remote LOAD decoder gap. `@P 0` re-LOAD remains as
  /// the fallback when progress events or seek are unavailable.
  static const int _warnLoopLeadFrames = 4;
  bool _warnLoopJumpPending = false;

  /// Serialize mpg123 remote stdin writes (concurrent flush →
  /// "StreamSink is bound to a stream" and breaks all later LOAD/STOP).
  Future<void> _remoteCmdChain = Future<void>.value();

  /// Legacy: sticky process started with `--loop` (kept for
  /// `_ensureRemoteMpg123` identity checks).
  bool _remoteLoopForever = false;

  final StreamController<bool> _playingCtrl =
      StreamController<bool>.broadcast();

  /// In-flight volume apply lock (latest-wins coalesce).
  bool _volumeBusy = false;
  int? _queuedVolume;

  static const _defaultPreferredVolumeControls = <String>[
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
  bool get hasActiveLoop =>
      _loopPath != null && _player != null && _remoteMode;

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
      final map = await readKeyValueConfFile(volumePreferencePath);
      final n = int.tryParse(map[OutputPrefs.keyVolume] ?? '');
      if (n != null) {
        _volumePercent = clampPercent(n);
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
      await upsertKeyValueConfFile(volumePreferencePath, {
        OutputPrefs.keyVolume: '$percent',
      });
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
        // Keep ALSA mixer near full scale; UI loudness is mpg123 soft-V
        // (click oneshot + warn loop share this path). rk809 DAC percent has
        // a large low-end dead zone (~0–50% ≈ mute) — do not drive warn via HW %.
        await _applyMixerVolume(100);
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
    _loopPath = null;
    await _ensureVolumeLoaded();
    await _ensurePlaybackPath();
    await _applyMixerVolume(100);

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
        await _runRemoteCmd(() => _remoteWriteln('LOAD $path'));
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

  List<String> _mpg123Args({required bool remote, bool loopForever = false}) {
    final args = <String>[];
    final dev = alsaOutputDevice.trim();
    if (dev.isNotEmpty) {
      args.addAll(<String>['-a', dev]);
    }
    // Optional CLI `--loop` (argv files only). Remote `LOAD` ignores this;
    // warn continuity uses `_reloadArmedWarnLoop` on `@P 0` instead.
    // NOTE: `-l` is --listentry, NOT loop.
    if (loopForever) {
      args.addAll(<String>['--loop', '-1']);
    }
    if (remote) {
      // Do not use -q: we need @P status lines for accurate play/stop state.
      args.add('-R');
    }
    return args;
  }

  Future<void> _startRemoteMpg123(
    String player, {
    bool loopForever = false,
  }) async {
    await _killRemoteMpg123();
    _player = await Process.start(
      player,
      _mpg123Args(remote: true, loopForever: loopForever),
    );
    _playerStdin = _player!.stdin;
    _remoteMode = true;
    _remoteLoopForever = loopForever;
    unawaited(_listenProcess(_player!));
  }

  Future<void> _killRemoteMpg123() async {
    final p = _player;
    final sink = _playerStdin;
    _player = null;
    _playerStdin = null;
    _remoteMode = false;
    // Keep _remoteLoopForever accurate after restart callers set it again.
    try {
      if (sink != null) {
        sink.writeln('QUIT');
        await sink.flush();
      }
    } catch (_) {}
    try {
      p?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    if (p != null) {
      try {
        await p.exitCode.timeout(const Duration(milliseconds: 300));
      } catch (_) {}
    }
  }

  Future<void> _ensureRemoteMpg123(
    String player, {
    required bool loopForever,
  }) async {
    if (_player != null &&
        _remoteMode &&
        _playerStdin != null &&
        _remoteLoopForever == loopForever) {
      return;
    }
    await _startRemoteMpg123(player, loopForever: loopForever);
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
    if (!_remoteMode || _playerStdin == null) {
      return;
    }
    // UI percent → mpg123 soft-V only (HW held near max in _drainVolumeQueue).
    await _runRemoteCmd(() => _remoteWriteln('V $percent'));
  }

  Future<void> _listenProcess(Process process) async {
    unawaited(_consumeLines(process.stdout, process, isStderr: false));
    unawaited(_consumeLines(process.stderr, process, isStderr: true));
    final code = await process.exitCode;
    if (identical(_player, process)) {
      _player = null;
      _playerStdin = null;
      _remoteMode = false;
      _remoteLoopForever = false;
      _loopPath = null;
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
        // mpg123 emits @F <current-frame> <remaining-frames> ... while playing.
        // Pre-roll an armed warning by seeking before EOF; this keeps the ALSA
        // device fed instead of waiting for @P 0 and reopening the MP3.
        if (t.startsWith('@F')) {
          _maybePreRollWarnLoop(t);
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
              // Remote LOAD does not honor `--loop`. While warn is armed,
              // re-LOAD on stop so the clip keeps cycling (same soft-V session).
              if (code == 0) {
                _warnLoopJumpPending = false;
                _reloadArmedWarnLoop();
              }
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
    await _applyMixerVolume(100);
    final player = await _resolvePlayerBinary();
    if (player == null || !_isMpg123(player)) {
      return;
    }
    await _ensureRemoteMpg123(player, loopForever: false);
    await _applyRemoteVolume(_volumePercent);
    lwsTrace('media-audio: click session warm');
  }



  Future<void> _runRemoteCmd(Future<void> Function() op) {
    final done = Completer<void>();
    _remoteCmdChain = _remoteCmdChain.then((_) async {
      try {
        await op();
        if (!done.isCompleted) {
          done.complete();
        }
      } catch (e, st) {
        if (!done.isCompleted) {
          done.completeError(e, st);
        }
      }
    });
    // Keep the chain alive even if [op] failed.
    _remoteCmdChain = _remoteCmdChain.catchError((_) {});
    return done.future;
  }

  Future<void> _remoteWriteln(String line) async {
    final sink = _playerStdin;
    if (sink == null || !_remoteMode) {
      return;
    }
    try {
      sink.writeln(line);
      await sink.flush();
    } catch (e) {
      debugPrint('media-audio: remote write failed ($line): $e');
      // Recover sticky session so later clicks are not permanently silent.
      try {
        await _killRemoteMpg123();
      } catch (_) {}
    }
  }

  void _maybePreRollWarnLoop(String status) {
    final path = _loopPath;
    final epoch = _warnLoopEpoch;
    if (path == null || _playerStdin == null || !_remoteMode) {
      return;
    }
    final parts = status.split(RegExp(r'\s+'));
    if (parts.length < 3) {
      return;
    }
    final currentFrame = int.tryParse(parts[1]);
    final remainingFrames = int.tryParse(parts[2]);
    if (currentFrame == null || remainingFrames == null) {
      return;
    }
    if (_warnLoopJumpPending) {
      // First progress sample after JUMP confirms that playback wrapped.
      if (currentFrame <= _warnLoopLeadFrames &&
          remainingFrames > _warnLoopLeadFrames) {
        _warnLoopJumpPending = false;
      }
      return;
    }
    if (currentFrame <= _warnLoopLeadFrames ||
        remainingFrames > _warnLoopLeadFrames) {
      return;
    }
    _warnLoopJumpPending = true;
    unawaited(_runRemoteCmd(() async {
      if (_loopPath != path || _warnLoopEpoch != epoch) {
        _warnLoopJumpPending = false;
        return;
      }
      await _remoteWriteln('JUMP 0');
      lwsTrace(
        'media-audio: warn loop pre-roll JUMP 0 '
        '(remaining=$remainingFrames frames)',
      );
    }));
  }

  /// End-of-track re-arm for [playLoopingAsset]. No-op if disarmed / no session.
  void _reloadArmedWarnLoop() {
    final path = _loopPath;
    final epoch = _warnLoopEpoch;
    if (path == null || _playerStdin == null || !_remoteMode) {
      return;
    }
    if (_loopPath != path || _warnLoopEpoch != epoch) {
      return;
    }
    unawaited(_runRemoteCmd(() async {
      if (_loopPath != path || _warnLoopEpoch != epoch) {
        return;
      }
      await _remoteWriteln('LOAD $path');
      if (_loopPath != path || _warnLoopEpoch != epoch) {
        await _remoteWriteln('STOP');
        return;
      }
      lwsTrace('media-audio: warn loop re-LOAD $path');
    }));
  }

  @override
  Future<void> playLoopingAsset(String assetKey) async {
    await _ensureVolumeLoaded();
    await _ensurePlaybackPath();
    // Same loudness path as click: HW near max + remote soft-V.
    await _applyMixerVolume(100);

    final path = await _ensureExtracted(assetKey);
    final player = await _resolvePlayerBinary();
    if (player == null || !_isMpg123(player)) {
      debugPrint('media-audio: warn loop needs mpg123 remote LOAD');
      return;
    }

    // Same file already armed — volume only; re-LOAD only if playback died.
    // Do not disarm/restart on same-code re-triggers (listen continuity).
    if (_loopPath == path &&
        _player != null &&
        _remoteMode &&
        _playerStdin != null) {
      await _applyRemoteVolume(_volumePercent);
      if (!_playing) {
        _reloadArmedWarnLoop();
      }
      return;
    }

    try {
      // loopForever false: `--loop` does not apply to remote LOAD; cycling is
      // done via `_reloadArmedWarnLoop` on `@P 0`.
      await _ensureRemoteMpg123(player, loopForever: false);
      await _applyRemoteVolume(_volumePercent);
      _warnLoopEpoch++;
      _loopPath = path;
      _warnLoopJumpPending = false;
      final armEpoch = _warnLoopEpoch;
      await _runRemoteCmd(() => _remoteWriteln('LOAD $path'));
      if (_loopPath != path || _warnLoopEpoch != armEpoch) {
        return;
      }
      _setPlaying(true);
      lwsTrace(
        'media-audio: warn loop LOAD $path (remote soft-V) vol=$_volumePercent%',
      );
    } catch (e) {
      _loopPath = null;
      _setPlaying(false);
      debugPrint('media-audio: warn loop start failed: $e');
    }
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

    // Mutual exclusion on the single remote session: warn loop owns the pipe;
    // do not LOAD a click over it (would tear the loop / race @P re-LOAD).
    if (_loopPath != null) {
      lwsTrace('media-audio: oneshot skipped (warn loop active)');
      return;
    }
    try {
      if (!_isMpg123(player)) {
        debugPrint('media-audio: oneshot needs mpg123 for remote LOAD');
        return;
      }
      await _ensureRemoteMpg123(player, loopForever: false);
      await _applyRemoteVolume(_volumePercent);
      await _runRemoteCmd(() => _remoteWriteln('LOAD $path'));
      lwsTrace('media-audio: oneshot LOAD $path (remote)');
    } catch (e) {
      debugPrint('media-audio: oneshot remote failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    // Disarm before STOP so the `@P 0` handler cannot re-LOAD.
    _warnLoopEpoch++;
    _loopPath = null;
    _warnLoopJumpPending = false;
    _setPlaying(false);
    if (_playerStdin == null) {
      return;
    }
    // Keep mpg123 -R alive so UI click oneshots can LOAD without fighting
    // exclusive plughw (a second mpg123 process exits 255 / is silent).
    await _runRemoteCmd(() => _remoteWriteln('STOP'));
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
    _loopPath = null;
    _warnLoopJumpPending = false;
    _remoteLoopForever = false;
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
