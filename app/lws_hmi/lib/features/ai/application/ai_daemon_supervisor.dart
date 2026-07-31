import 'dart:async';
import 'dart:io';

import 'package:cyber_pm/cyber_pm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_protocol.dart';
import 'package:lws_hmi/features/ai/application/camera_ai_http_publisher.dart';

/// App-owned AI daemon lifecycle: spawn via [cyber_pm], Unix sockets, StreamDetect cmds.
final class AiDaemonSupervisor {
  factory AiDaemonSupervisor({
    ProcessSupervisor? processSupervisor,
    AiDaemonSocketClient? socketClient,
    CameraAiHttpPublisher? cameraAiPublisher,
    String daemonPath = '/opt/hmi/bin/lws_ai_daemon',
    String workdir = '/var/lib/hmi/ai',
    String sockDir = '/run/hmi/ai',
  }) {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }
    return _instance = AiDaemonSupervisor._(
      processSupervisor: processSupervisor,
      socketClient: socketClient,
      cameraAiPublisher: cameraAiPublisher,
      daemonPath: daemonPath,
      workdir: workdir,
      sockDir: sockDir,
    );
  }

  AiDaemonSupervisor._({
    ProcessSupervisor? processSupervisor,
    AiDaemonSocketClient? socketClient,
    CameraAiHttpPublisher? cameraAiPublisher,
    required this.daemonPath,
    required this.workdir,
    required this.sockDir,
  })  : _supervisor = processSupervisor ??
            ProcessSupervisor(
              restartPolicy: const RestartPolicy.onFailure(
                delay: Duration(seconds: 3),
              ),
              logSink: (line) => debugPrint('[lws_ai_daemon] $line'),
            ),
        _sockets = socketClient ??
            AiDaemonSocketClient(
              cmdPath: '$sockDir/cmd.sock',
              evtPath: '$sockDir/evt.sock',
            ),
        cameraAiPublisher = cameraAiPublisher ?? CameraAiHttpPublisher(
              searchRoots: () => [
                Directory(workdir),
                Directory('$workdir/lens_guard'),
              ],
            );

  static AiDaemonSupervisor? _instance;

  /// Shared product instance (created on first [AiDaemonSupervisor] call).
  static AiDaemonSupervisor get instance => AiDaemonSupervisor();

  @visibleForTesting
  static void resetInstanceForTest() {
    _instance = null;
  }

  final ProcessSupervisor _supervisor;
  final AiDaemonSocketClient _sockets;
  final CameraAiHttpPublisher cameraAiPublisher;
  final String daemonPath;
  final String workdir;
  final String sockDir;

  StreamSubscription<String>? _evtSub;
  bool _started = false;
  String? lastError;
  String? lastOutputDir;
  String? lastRtspUrl;
  String lastSessionSource = 'live_stain_detect';

  bool get isStarted => _started;
  bool get isProcessRunning => _supervisor.isRunning;
  bool get isReady => _started && _sockets.isConnected;

  /// Non-fatal: missing binary records [lastError] and returns false.
  Future<bool> ensureStarted({
    Duration readyTimeout = const Duration(seconds: 10),
  }) async {
    lastError = null;
    if (!Platform.isLinux) {
      lastError = 'AI daemon only on Linux';
      return false;
    }
    if (_started && _sockets.isConnected) {
      return true;
    }
    final bin = File(daemonPath);
    if (!await bin.exists()) {
      lastError = 'missing $daemonPath (make build-ai && make build-app)';
      debugPrint('[ai_daemon] $lastError');
      return false;
    }

    await Directory(workdir).create(recursive: true);
    await Directory(sockDir).create(recursive: true);
    for (final name in const ['cmd.sock', 'evt.sock']) {
      final f = File('$sockDir/$name');
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    await _supervisor.start(
      executable: daemonPath,
      arguments: <String>[
        '--workdir',
        workdir,
        '--sock-dir',
        sockDir,
      ],
      workingDirectory: workdir,
      environment: <String, String>{
        'LD_LIBRARY_PATH':
            '/opt/hmi/lib:${Platform.environment['LD_LIBRARY_PATH'] ?? ''}',
      },
      logPrefix: 'lws_ai_daemon',
    );

    final deadline = DateTime.now().add(readyTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await File('$sockDir/cmd.sock').exists() &&
          await File('$sockDir/evt.sock').exists()) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    try {
      await _sockets.connect(timeout: const Duration(seconds: 3));
      _attachEvtBridge();
      final ping = AiDaemonProtocol.pingRequest();
      final id = ping['id']!.toString();
      final resp = await _sockets.request(ping);
      if (!AiDaemonProtocol.isPingAck(resp, id: id)) {
        lastError = 'unexpected ping response: $resp';
        debugPrint('[ai_daemon] $lastError');
        return false;
      }
      _started = true;
      debugPrint('[ai_daemon] ready (ping_ack id=$id)');
      return true;
    } catch (e, st) {
      lastError = e.toString();
      debugPrint('[ai_daemon] connect/ping failed: $e\n$st');
      return false;
    }
  }

  void _attachEvtBridge() {
    unawaited(_evtSub?.cancel());
    _evtSub = _sockets.evtLines.listen((line) {
      final obj = AiDaemonProtocol.tryDecodeLine(line);
      if (obj == null) {
        return;
      }
      final type = obj['type']?.toString() ?? '';
      if (type == 'heartbeat' || type == 'daemon_ready') {
        return;
      }
      if (type == 'error' || type == 'health') {
        debugPrint('[ai_daemon] evt $type $obj');
        return;
      }
      if (type == 'detect_result' ||
          type == 'combined_frame' ||
          type == 'session_start' ||
          type == 'session_stop' ||
          type == 'pipeline_state') {
        cameraAiPublisher.ingestDaemonEvent(obj);
      }
    });
  }

  Future<bool> pushLaserState(bool laserOn) async {
    if (!_sockets.isConnected) {
      return false;
    }
    try {
      final resp = await _sockets.request(
        AiDaemonProtocol.cmd(
          'laser_state',
          fields: <String, Object?>{'laser_on': laserOn},
        ),
      );
      return resp['ok'] == true;
    } catch (e) {
      debugPrint('[ai_daemon] laser_state failed: $e');
      return false;
    }
  }

  Future<bool> pushAiAssistConfig({
    required bool lensContaminationEnabled,
    required bool zeroPointOffsetEnabled,
  }) async {
    if (!_sockets.isConnected) {
      return false;
    }
    try {
      final resp = await _sockets.request(
        AiDaemonProtocol.cmd(
          'ai_assist_config',
          fields: <String, Object?>{
            'lens_contamination_enabled': lensContaminationEnabled,
            'zero_point_offset_enabled': zeroPointOffsetEnabled,
          },
        ),
      );
      return resp['ok'] == true;
    } catch (e) {
      debugPrint('[ai_daemon] ai_assist_config failed: $e');
      return false;
    }
  }

  Future<bool> configureStreamDetect({
    required String outputDir,
    required bool lensDetEnabled,
    required bool zeroPointEnabled,
    String sessionSource = 'live_stain_detect',
    int cameraType = 0,
    bool rknnStreamEnabled = false,
  }) async {
    if (!_sockets.isConnected) {
      return false;
    }
    try {
      final resp = await _sockets.request(
        AiDaemonProtocol.cmd(
          'configure_session',
          fields: <String, Object?>{
            'output_dir': outputDir,
            'camera_type': cameraType,
            'lens_det_enabled': lensDetEnabled,
            'zero_point_enabled': zeroPointEnabled,
            'session_source': sessionSource,
            'project_root': '.',
            'config_yaml': 'config.yaml',
            'roi_json': 'zero_point_roi.json',
            'rknn_stream_enabled': rknnStreamEnabled,
          },
        ),
      );
      final ok = resp['ok'] == true;
      if (ok) {
        lastOutputDir = outputDir;
        lastSessionSource = sessionSource;
      }
      return ok;
    } catch (e) {
      debugPrint('[ai_daemon] configure_session failed: $e');
      return false;
    }
  }

  Future<bool> startStreamDetect(String rtspUrl) async {
    if (!_sockets.isConnected) {
      return false;
    }
    try {
      final resp = await _sockets.request(
        AiDaemonProtocol.cmd(
          'stream_detect_start',
          fields: <String, Object?>{'rtsp_url': rtspUrl},
        ),
      );
      final ok = resp['ok'] == true;
      if (ok) {
        lastRtspUrl = rtspUrl;
      }
      return ok;
    } catch (e) {
      debugPrint('[ai_daemon] stream_detect_start failed: $e');
      return false;
    }
  }

  Future<bool> stopStreamDetect() async {
    if (!_sockets.isConnected) {
      return false;
    }
    try {
      final resp = await _sockets.request(
        AiDaemonProtocol.cmd('stream_detect_stop'),
      );
      return resp['ok'] == true;
    } catch (e) {
      debugPrint('[ai_daemon] stream_detect_stop failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    await _evtSub?.cancel();
    _evtSub = null;
    await _sockets.disconnect();
    await _supervisor.stop();
    _started = false;
  }
}
