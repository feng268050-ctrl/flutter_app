import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_hub.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/ai/application/opencv_stain_detect_mapper.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_frame_sampler.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_timeline.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

enum ProcessVideoAiHolder { ui, http }

enum ProcessVideoAiCreateFailure {
  sourceInvalid,
  engineNotReady,
  durationUnavailable,
}

final class ProcessVideoAiCreateResult {
  const ProcessVideoAiCreateResult._({this.session, this.failure});

  final ProcessVideoAiSession? session;
  final ProcessVideoAiCreateFailure? failure;

  bool get isOk => session != null;

  factory ProcessVideoAiCreateResult.ok(ProcessVideoAiSession session) =>
      ProcessVideoAiCreateResult._(session: session);

  factory ProcessVideoAiCreateResult.fail(ProcessVideoAiCreateFailure failure) =>
      ProcessVideoAiCreateResult._(failure: failure);
}

/// Offline process-video Detect session (lws-ui `ProcessVideoAiSession` parity).
final class ProcessVideoAiSession {
  ProcessVideoAiSession._({
    required this.record,
    required this.sourceFile,
    required this.cacheKey,
    required this.durationMs,
    required AiDaemonSupervisor supervisor,
    ProcessVideoAiFrameSampler? sampler,
  })  : _supervisor = supervisor,
        _sampler = sampler ?? ProcessVideoAiFrameSampler(),
        timeline = ProcessVideoAiTimeline(
          cacheKey: cacheKey,
          durationMs: durationMs,
          sampleIntervalMs: ProcessVideoAiInferencePaths.sampleIntervalMs,
        ) {
    sseHub = AiInferenceSseHub.forProcessVideo(
      mediaPositionMs: () => playbackPositionMs,
    );
  }

  static const playbackFps = 15;
  static const playbackFrameStepMs = 1000 ~/ playbackFps;
  static const offlineSource = OpencvStainDetectMapper.offlineSource;

  final ProcessVideoRecord record;
  final File sourceFile;
  final String cacheKey;
  final int durationMs;
  final ProcessVideoAiTimeline timeline;
  late final AiInferenceSseHub sseHub;

  final AiDaemonSupervisor _supervisor;
  final ProcessVideoAiFrameSampler _sampler;

  int _uiRefs = 0;
  int _httpRefs = 0;
  bool _running = false;
  bool _finalized = false;
  bool _playbackEnded = false;
  int playbackPositionMs = 0;
  int _nextClockPositionMs = 0;
  int _lastScheduledSampleMs = -1;
  String? _sseSessionId;
  Timer? _clockTimer;
  Future<void> _inferChain = Future<void>.value();

  final _timelineListeners = <void Function(ProcessVideoAiTimelineFrame)>[];
  void Function(ProcessVideoAiSession session)? onPlaybackEnded;
  void Function(ProcessVideoAiSession session)? onFinalize;
  bool _playbackPaused = false;

  String get videoId => record.videoId;

  bool get isRunning => _running && !_finalized;

  bool get hasPlaybackEnded => _playbackEnded;

  bool get isPlaybackPaused => _playbackPaused;

  File get timelineFile =>
      ProcessVideoAiInferencePaths.timelineJson(record, cacheKey);

  void addTimelineListener(void Function(ProcessVideoAiTimelineFrame) listener) {
    _timelineListeners.add(listener);
  }

  void removeTimelineListener(
    void Function(ProcessVideoAiTimelineFrame) listener,
  ) {
    _timelineListeners.remove(listener);
  }

  void pausePlaybackClock() {
    if (!_playbackEnded) {
      _playbackPaused = true;
    }
  }

  void resumePlaybackClock() {
    if (!_playbackEnded) {
      _playbackPaused = false;
    }
  }

  void addRef(ProcessVideoAiHolder holder) {
    if (holder == ProcessVideoAiHolder.ui) {
      _uiRefs++;
    } else {
      _httpRefs++;
    }
  }

  int releaseRef(ProcessVideoAiHolder holder) {
    if (holder == ProcessVideoAiHolder.ui) {
      _uiRefs = max(0, _uiRefs - 1);
    } else {
      _httpRefs = max(0, _httpRefs - 1);
    }
    return _uiRefs + _httpRefs;
  }

  static ProcessVideoAiCreateResult tryCreate({
    required ProcessVideoRecord record,
    required File sourceFile,
    required String cacheKey,
    AiDaemonSupervisor? supervisor,
    ProcessVideoAiFrameSampler? sampler,
  }) {
    final ai = supervisor ?? AiDaemonSupervisor.instance;
    if (!sourceFile.existsSync() || sourceFile.lengthSync() <= 0) {
      return ProcessVideoAiCreateResult.fail(
        ProcessVideoAiCreateFailure.sourceInvalid,
      );
    }
    if (!ai.isReady) {
      return ProcessVideoAiCreateResult.fail(
        ProcessVideoAiCreateFailure.engineNotReady,
      );
    }
    final durationMs = record.durationMs;
    if (durationMs <= 0) {
      return ProcessVideoAiCreateResult.fail(
        ProcessVideoAiCreateFailure.durationUnavailable,
      );
    }
    return ProcessVideoAiCreateResult.ok(
      ProcessVideoAiSession._(
        record: record,
        sourceFile: sourceFile,
        cacheKey: cacheKey,
        durationMs: durationMs,
        supervisor: ai,
        sampler: sampler,
      ),
    );
  }

  /// Maps playback clock to sample grid; first sample at [intervalMs]; 0 never sampled.
  @visibleForTesting
  static int sampleMsForClockPosition(int clockPosMs, int intervalMs) {
    if (intervalMs <= 0) {
      return -1;
    }
    final bucket = (clockPosMs ~/ intervalMs) * intervalMs;
    if (bucket < intervalMs) {
      return -1;
    }
    return bucket;
  }

  bool start() {
    if (_running) {
      return true;
    }
    _running = true;
    _finalized = false;
    _playbackEnded = false;
    _playbackPaused = false;
    playbackPositionMs = 0;
    _nextClockPositionMs = 0;
    _lastScheduledSampleMs = -1;
    timeline.clear();
    _sseSessionId = _newSessionId();
    sseHub.notifySessionStarted(
      AiInferenceSessionStart(
        sessionId: _sseSessionId!,
        source: offlineSource,
        samplingIntervalMs: ProcessVideoAiInferencePaths.sampleIntervalMs,
      ),
    );
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: playbackFrameStepMs),
      (_) => _clockTick(),
    );
    debugPrint(
      '[process_video_ai] start videoId=$videoId durationMs=$durationMs',
    );
    return true;
  }

  void stop({String reason = 'release'}) {
    if (!_running) {
      return;
    }
    _running = false;
    _clockTimer?.cancel();
    _clockTimer = null;
    _playbackEnded = true;
    unawaited(_finalize(reason: reason));
  }

  AiInferenceSseSubscriber? acquireSseSubscriber() {
    if (!_running) {
      return null;
    }
    return sseHub.acquire();
  }

  void _clockTick() {
    if (!_running || _playbackEnded || _playbackPaused) {
      return;
    }
    if (durationMs > 0 && _nextClockPositionMs >= durationMs) {
      _onPlaybackEnded();
      return;
    }
    final posMs = _nextClockPositionMs;
    final sampleMs = sampleMsForClockPosition(
      posMs,
      ProcessVideoAiInferencePaths.sampleIntervalMs,
    );
    _scheduleInferSample(sampleMs);
    playbackPositionMs = posMs;
    _nextClockPositionMs += playbackFrameStepMs;
    if (durationMs > 0 && _nextClockPositionMs >= durationMs) {
      _onPlaybackEnded();
    }
  }

  void _scheduleInferSample(int sampleMs) {
    if (!_running || _playbackEnded || sampleMs < 0) {
      return;
    }
    if (sampleMs <= _lastScheduledSampleMs) {
      return;
    }
    if (timeline.hasSampleAt(sampleMs)) {
      _lastScheduledSampleMs = sampleMs;
      return;
    }
    _lastScheduledSampleMs = sampleMs;
    _inferChain = _inferChain.then((_) => _runInferSample(sampleMs));
  }

  Future<void> _runInferSample(int sampleMs) async {
    if (_finalized) {
      return;
    }
    final jpeg = await _sampler.extractJpegAt(
      videoPath: sourceFile.path,
      videoId: videoId,
      sampleMs: sampleMs,
    );
    if (jpeg == null || _finalized) {
      return;
    }
    final outDir =
        '${_supervisor.workdir}/opencv_stain_detect_out/offline/$videoId/$sampleMs';
    final sample = await _supervisor.offlineInferOpencvStainJpg(
      imagePath: jpeg.path,
      outputDir: outDir,
      source: offlineSource,
    );
    if (_finalized) {
      return;
    }
    final frame = ProcessVideoAiTimelineFrame(timeMs: sampleMs, sample: sample);
    timeline.addFrame(frame);
    sseHub.publishRunning(
      sample,
      contextMs: sampleMs,
      sessionId: _sseSessionId,
    );
    for (final listener in List.of(_timelineListeners)) {
      listener(frame);
    }
  }

  void _onPlaybackEnded() {
    if (_playbackEnded) {
      return;
    }
    _playbackEnded = true;
    _running = false;
    _clockTimer?.cancel();
    _clockTimer = null;
    onPlaybackEnded?.call(this);
    unawaited(_finalize(reason: 'session_complete'));
  }

  Future<void> _finalize({required String reason}) async {
    if (_finalized) {
      return;
    }
    // Drain in-flight infer samples.
    await _inferChain;
    if (_finalized) {
      return;
    }
    _finalized = true;
    final stopMs = durationMs > 0 ? durationMs : max(0, playbackPositionMs);
    final sid = _sseSessionId;
    if (sid != null) {
      sseHub.notifySessionStopped(
        sessionId: sid,
        reason: reason,
        contextMs: stopMs,
      );
      _sseSessionId = null;
    }
    try {
      await ProcessVideoAiTimelinePersistence.save(timelineFile, timeline);
    } catch (e) {
      debugPrint('[process_video_ai] persist timeline failed: $e');
    }
    debugPrint(
      '[process_video_ai] finalize videoId=$videoId reason=$reason '
      'frames=${timeline.snapshotFrames().length}',
    );
    onFinalize?.call(this);
  }

  static String _newSessionId() {
    final r = Random.secure();
    return 'pv_${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }
}

/// Single-flight sessions keyed by inference cache key.
final class ProcessVideoAiSessionRegistry {
  ProcessVideoAiSessionRegistry._();

  static final ProcessVideoAiSessionRegistry instance =
      ProcessVideoAiSessionRegistry._();

  final Map<String, ProcessVideoAiSession> _sessions = {};

  @visibleForTesting
  void resetForTest() {
    for (final s in _sessions.values) {
      s.stop(reason: 'test_reset');
    }
    _sessions.clear();
  }

  ProcessVideoAiSession? peekByCacheKey(String cacheKey) => _sessions[cacheKey];

  ProcessVideoAiSession? acquire({
    required ProcessVideoRecord record,
    required File sourceFile,
    required ProcessVideoAiHolder holder,
    bool force = false,
    AiDaemonSupervisor? supervisor,
  }) {
    final cacheKey = ProcessVideoAiInferencePaths.cacheKey(record, sourceFile);
    final existing = _sessions[cacheKey];
    if (existing != null) {
      if (force) {
        existing.stop(reason: 'force_restart');
        _sessions.remove(cacheKey);
      } else {
        existing.addRef(holder);
        return existing;
      }
    }
    final created = ProcessVideoAiSession.tryCreate(
      record: record,
      sourceFile: sourceFile,
      cacheKey: cacheKey,
      supervisor: supervisor,
    );
    if (!created.isOk) {
      debugPrint(
        '[process_video_ai] acquire failed videoId=${record.videoId} '
        'failure=${created.failure}',
      );
      return null;
    }
    final session = created.session!;
    session.addRef(holder);
    _sessions[cacheKey] = session;
    return session;
  }

  void release(ProcessVideoAiSession session, ProcessVideoAiHolder holder) {
    final refs = session.releaseRef(holder);
    if (refs > 0) {
      return;
    }
    session.stop(reason: 'release');
    _sessions.remove(session.cacheKey);
  }
}
