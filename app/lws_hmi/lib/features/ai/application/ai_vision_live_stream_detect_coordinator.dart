import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/ai/application/live_weld_stream_detect_coordinator.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';

/// AI Vision live holder (`sessionSource: ai_vision_live`); yields to weld.
final class AiVisionLiveStreamDetectCoordinator {
  AiVisionLiveStreamDetectCoordinator({
    required this.aiAssistance,
    AiDaemonSupervisor? supervisor,
    this.rtspUrl = 'rtsp://127.0.0.1:8554/camera/pr1',
    bool Function()? weldHolderRunning,
  })  : _supervisor = supervisor ?? AiDaemonSupervisor.instance,
        _weldHolderRunning = weldHolderRunning ?? _defaultWeldRunning;

  static bool _defaultWeldRunning() =>
      LiveWeldStreamDetectCoordinator.maybeInstance?.isRunning == true;

  static const sessionSource = 'ai_vision_live';
  static const samplingIntervalMs = 500;

  final AiAssistanceSettings aiAssistance;
  final AiDaemonSupervisor _supervisor;
  final String rtspUrl;
  final bool Function() _weldHolderRunning;

  bool _active = false;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> setActive(bool active) async {
    if (_active == active) {
      return;
    }
    _active = active;
    if (_active) {
      aiAssistance.addListener(_onAssistChanged);
    } else {
      aiAssistance.removeListener(_onAssistChanged);
    }
    await _reconcile();
  }

  void _onAssistChanged() {
    unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    final want = _active && aiAssistance.lensContaminationDetectionEnabled;
    if (want && _weldHolderRunning()) {
      if (_running) {
        await _stopPipeline('preview_stopped');
      }
      return;
    }
    if (want && !_running) {
      await _startPipeline();
    } else if (!want && _running) {
      await _stopPipeline('preview_stopped');
    }
  }

  Future<void> _startPipeline() async {
    if (!_supervisor.isReady) {
      final ok = await _supervisor.ensureStarted();
      if (!ok) {
        return;
      }
    }
    if (_weldHolderRunning()) {
      return;
    }
    final outDir = Directory('${_supervisor.workdir}/lens_guard');
    await outDir.create(recursive: true);
    await _supervisor.pushAiAssistConfig(
      lensContaminationEnabled: aiAssistance.lensContaminationDetectionEnabled,
      zeroPointOffsetEnabled: aiAssistance.zeroPointOffsetDetectionEnabled,
    );
    final configured = await _supervisor.configureStreamDetect(
      outputDir: outDir.path,
      lensDetEnabled: true,
      zeroPointEnabled: aiAssistance.zeroPointOffsetDetectionEnabled,
      sessionSource: sessionSource,
    );
    if (!configured) {
      debugPrint('[ai_vision_live] configure_session failed');
      return;
    }
    _supervisor.cameraAiPublisher.onInferenceSessionStart(
      source: sessionSource,
      samplingIntervalMs: samplingIntervalMs,
    );
    await _supervisor.pushLaserState(true);
    final started = await _supervisor.startStreamDetect(rtspUrl);
    if (!started) {
      debugPrint('[ai_vision_live] stream_detect_start failed');
      return;
    }
    _running = true;
    debugPrint('[ai_vision_live] stream detect started');
  }

  Future<void> _stopPipeline(String reason) async {
    await _supervisor.pushLaserState(false);
    await _supervisor.stopStreamDetect();
    _supervisor.cameraAiPublisher.onInferenceSessionStop(reason);
    _running = false;
    debugPrint('[ai_vision_live] stopped reason=$reason');
  }
}
