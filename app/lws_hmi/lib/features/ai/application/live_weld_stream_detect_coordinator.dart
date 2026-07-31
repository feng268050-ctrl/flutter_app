import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';

/// Weld holder for daemon-hosted StreamDetect (laser ON → PR1 infer).
final class LiveWeldStreamDetectCoordinator {
  LiveWeldStreamDetectCoordinator({
    required this.services,
    required this.aiAssistance,
    AiDaemonSupervisor? supervisor,
    this.rtspUrl = 'rtsp://127.0.0.1:8554/camera/pr1',
  }) : _supervisor = supervisor ?? AiDaemonSupervisor.instance;

  final AppServices services;
  final AiAssistanceSettings aiAssistance;
  final AiDaemonSupervisor _supervisor;
  final String rtspUrl;

  StreamSubscription<List<ModbusAttributeChange>>? _watchSub;
  bool _laserEnable = false;
  bool _laserOn = false;
  bool _running = false;
  bool _started = false;

  bool get isRunning => _running;

  bool get _laserActive => _laserEnable || _laserOn;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    aiAssistance.addListener(_onAssistChanged);
    try {
      await services.ensureModbusLive();
      final stream = await services.modbus.watchAttributes(
        ids: const [
          LaserWorkGuard.laserEnableAttribute,
          LaserWorkGuard.laserOnAttribute,
        ],
      );
      _watchSub = stream.listen(_onLaserChanges);
    } catch (e) {
      debugPrint('[ai_weld] watchAttributes failed: $e');
    }
    unawaited(_syncAssistConfig());
  }

  Future<void> stop() async {
    _started = false;
    aiAssistance.removeListener(_onAssistChanged);
    await _watchSub?.cancel();
    _watchSub = null;
    if (_running) {
      await _stopPipeline('release');
    }
  }

  void _onAssistChanged() {
    unawaited(_syncAssistConfig());
    unawaited(_reconcile());
  }

  void _onLaserChanges(List<ModbusAttributeChange> changes) {
    var changed = false;
    for (final c in changes) {
      final on = c.value == true || c.value == 1;
      switch (c.id) {
        case LaserWorkGuard.laserEnableAttribute:
          if (_laserEnable != on) {
            _laserEnable = on;
            changed = true;
          }
          break;
        case LaserWorkGuard.laserOnAttribute:
          if (_laserOn != on) {
            _laserOn = on;
            changed = true;
          }
          break;
      }
    }
    if (changed) {
      unawaited(_reconcile());
    }
  }

  Future<void> _reconcile() async {
    final want = _laserActive && aiAssistance.lensContaminationDetectionEnabled;
    if (want && !_running) {
      await _startPipeline();
    } else if (!want && _running) {
      await _stopPipeline(_laserActive ? 'preview_stopped' : 'laser_off');
    } else if (_running) {
      await _supervisor.pushLaserState(_laserActive);
    }
  }

  Future<void> _syncAssistConfig() async {
    if (!_supervisor.isReady) {
      return;
    }
    await _supervisor.pushAiAssistConfig(
      lensContaminationEnabled: aiAssistance.lensContaminationDetectionEnabled,
      zeroPointOffsetEnabled: aiAssistance.zeroPointOffsetDetectionEnabled,
    );
  }

  Future<void> _startPipeline() async {
    if (!_supervisor.isReady) {
      final ok = await _supervisor.ensureStarted();
      if (!ok) {
        return;
      }
    }
    final outDir = Directory('${_supervisor.workdir}/lens_guard');
    await outDir.create(recursive: true);
    await _syncAssistConfig();
    final configured = await _supervisor.configureStreamDetect(
      outputDir: outDir.path,
      lensDetEnabled: aiAssistance.lensContaminationDetectionEnabled,
      zeroPointEnabled: aiAssistance.zeroPointOffsetDetectionEnabled,
      sessionSource: 'live_stain_detect',
    );
    if (!configured) {
      debugPrint('[ai_weld] configure_session failed');
      return;
    }
    await _supervisor.pushLaserState(true);
    final started = await _supervisor.startStreamDetect(rtspUrl);
    if (!started) {
      debugPrint('[ai_weld] stream_detect_start failed url=$rtspUrl');
      return;
    }
    _running = true;
    debugPrint('[ai_weld] stream detect started');
  }

  Future<void> _stopPipeline(String reason) async {
    await _supervisor.pushLaserState(false);
    await _supervisor.stopStreamDetect();
    _running = false;
    // Native `session_stop` on evt.sock drives SSE stop (mapped to laser_off).
    debugPrint('[ai_weld] stream detect stopped reason=$reason');
  }
}
