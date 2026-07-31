import 'dart:io';

import 'package:cyber_pm/cyber_pm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_protocol.dart';

/// App-owned AI daemon lifecycle (P3.3 smoke): spawn via [cyber_pm], connect
/// Unix sockets, wait for `daemon_ready`, optional `ping`.
final class AiDaemonSupervisor {
  AiDaemonSupervisor({
    ProcessSupervisor? processSupervisor,
    AiDaemonSocketClient? socketClient,
    this.daemonPath = '/opt/hmi/bin/lws_ai_daemon',
    this.workdir = '/var/lib/hmi/ai',
    this.sockDir = '/run/hmi/ai',
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
            );

  final ProcessSupervisor _supervisor;
  final AiDaemonSocketClient _sockets;
  final String daemonPath;
  final String workdir;
  final String sockDir;

  bool _started = false;
  String? lastError;

  bool get isStarted => _started;
  bool get isProcessRunning => _supervisor.isRunning;

  /// Non-fatal: missing binary records [lastError] and returns false.
  Future<bool> ensureStarted({
    Duration readyTimeout = const Duration(seconds: 10),
  }) async {
    lastError = null;
    if (!Platform.isLinux) {
      lastError = 'AI daemon only on Linux';
      return false;
    }
    final bin = File(daemonPath);
    if (!await bin.exists()) {
      lastError = 'missing $daemonPath (make build-ai && make build-app)';
      debugPrint('[ai_daemon] $lastError');
      return false;
    }

    await Directory(workdir).create(recursive: true);
    await Directory(sockDir).create(recursive: true);
    // Clear stale sockets before spawn.
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
        'LD_LIBRARY_PATH': '/opt/hmi/lib:${Platform.environment['LD_LIBRARY_PATH'] ?? ''}',
      },
      logPrefix: 'lws_ai_daemon',
    );

    // Wait briefly for listen sockets to appear, then connect.
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
      // daemon_ready may have been published before we subscribed; ping is enough.
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

  Future<void> stop() async {
    await _sockets.disconnect();
    await _supervisor.stop();
    _started = false;
  }
}
