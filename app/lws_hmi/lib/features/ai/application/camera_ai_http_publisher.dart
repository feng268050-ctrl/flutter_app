import 'dart:io';
import 'dart:math';

import 'package:lws_hmi/features/ai/application/ai_inference_sse_hub.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/ai/application/opencv_stain_detect_mapper.dart';

/// Reference-counted SSE inference stream for `GET /v1/camera/ai`.
final class CameraAiHttpPublisher {
  CameraAiHttpPublisher({
    AiInferenceSseHub? hub,
    OpencvStainDetectMapper mapper = const OpencvStainDetectMapper(),
    List<Directory> Function()? searchRoots,
  })  : _hub = hub ?? AiInferenceSseHub(),
        _mapper = mapper,
        _searchRoots = searchRoots;

  final AiInferenceSseHub _hub;
  final OpencvStainDetectMapper _mapper;
  final List<Directory> Function()? _searchRoots;

  String? _activeSessionSource;
  int _lastImageWidth = 0;
  int _lastImageHeight = 0;

  AiInferenceSseHub get hub => _hub;

  int get subscriberCount => _hub.subscriberCount;

  AiInferenceSseSubscriber acquire() {
    return _hub.acquire();
  }

  void ingestDaemonEvent(Map<String, dynamic> evt) {
    final type = evt['type']?.toString() ?? '';
    switch (type) {
      case 'detect_result':
        _onDetectResult(evt);
        break;
      case 'session_start':
        _onSessionStart(evt);
        break;
      case 'session_stop':
        _onSessionStop(evt);
        break;
      case 'pipeline_state':
        _onPipelineState(evt);
        break;
    }
  }

  void onInferenceSessionStart({
    required String source,
    required int samplingIntervalMs,
    int imageWidth = 0,
    int imageHeight = 0,
  }) {
    if (source == 'ai_vision_live' &&
        _activeSessionSource == OpencvStainDetectMapper.liveSource) {
      return;
    }
    if (source == _activeSessionSource && _hub.hasActiveSession) {
      return;
    }
    if (source == OpencvStainDetectMapper.liveSource &&
        _activeSessionSource != null) {
      final oldId = _hub.activeSessionId;
      if (oldId != null) {
        _hub.notifySessionStopped(sessionId: oldId, reason: 'preview_stopped');
      }
    }
    _activeSessionSource = source;
    final w = imageWidth > 0 ? imageWidth : _lastImageWidth;
    final h = imageHeight > 0 ? imageHeight : _lastImageHeight;
    _hub.notifySessionStarted(
      AiInferenceSessionStart(
        sessionId: _newSessionId(),
        source: source,
        samplingIntervalMs: samplingIntervalMs > 0 ? samplingIntervalMs : 500,
        imageWidth: w > 0 ? w : null,
        imageHeight: h > 0 ? h : null,
      ),
    );
  }

  void onInferenceSessionStop(String reason) {
    if (!_hub.hasActiveSession) {
      _activeSessionSource = null;
      return;
    }
    final sessionId = _hub.activeSessionId;
    _activeSessionSource = null;
    if (sessionId == null) {
      return;
    }
    _hub.notifySessionStopped(sessionId: sessionId, reason: reason);
  }

  void resetForTest() {
    _activeSessionSource = null;
    _lastImageWidth = 0;
    _lastImageHeight = 0;
    _hub.resetForTest();
  }

  void _onDetectResult(Map<String, dynamic> evt) {
    if (evt['module']?.toString() != 'lens_det') {
      return;
    }
    _lastImageWidth = _asInt(evt['imageWidth']) ?? _lastImageWidth;
    _lastImageHeight = _asInt(evt['imageHeight']) ?? _lastImageHeight;
    final source = _activeSessionSource ?? OpencvStainDetectMapper.liveSource;
    final roots = _searchRoots?.call() ?? const <Directory>[];
    final sample = _mapper.fromDetectResult(
      event: evt,
      source: source,
      searchRoots: roots,
    );
    _hub.publishRunning(sample);
  }

  void _onSessionStart(Map<String, dynamic> evt) {
    final source = (evt['source']?.toString().isNotEmpty ?? false)
        ? evt['source']!.toString()
        : OpencvStainDetectMapper.liveSource;
    final interval = _asInt(evt['samplingIntervalMs']) ?? 500;
    onInferenceSessionStart(
      source: source,
      samplingIntervalMs: interval,
      imageWidth: _lastImageWidth,
      imageHeight: _lastImageHeight,
    );
  }

  void _onSessionStop(Map<String, dynamic> evt) {
    final reason = mapNativeSessionStopReason(evt['reason']?.toString() ?? '');
    onInferenceSessionStop(reason);
  }

  void _onPipelineState(Map<String, dynamic> evt) {
    if (evt['state']?.toString() != 'error') {
      return;
    }
    final detail = evt['detail']?.toString() ?? '';
    _hub.publishError(
      code: -1,
      message: detail.isEmpty ? 'stream_detect_error' : detail,
    );
    _activeSessionSource = null;
  }

  static String mapNativeSessionStopReason(String reason) {
    if (reason == 'release' || reason == 'laser_enable_off') {
      return 'laser_off';
    }
    return reason.isEmpty ? 'stream_error' : reason;
  }

  static String _newSessionId() {
    final r = Random.secure();
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '$ms-${r.nextInt(1 << 32).toRadixString(16)}';
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}
