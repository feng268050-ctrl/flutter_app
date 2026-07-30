import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_pm/cyber_pm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/ip_camera/application/media_mtx_config_writer.dart';

enum IpCameraRelayPhase { stopped, starting, running, error }

final class IpCameraRelayStatus {
  const IpCameraRelayStatus({
    required this.phase,
    this.detail,
  });

  final IpCameraRelayPhase phase;
  final String? detail;

  static const stopped = IpCameraRelayStatus(phase: IpCameraRelayPhase.stopped);
}

/// Product MediaMTX on-demand lifecycle (not part of portable ip_camera HAL).
abstract class IpCameraMediaMtxRelay {
  IpCameraRelayStatus get currentStatus;

  /// Local fan-out URLs when running.
  Uri get localPr0;
  Uri get localPr1;

  Future<void> ensureStarted(IpCameraStreams upstream);
  Future<void> stop();
}

final class LinuxIpCameraMediaMtxRelay implements IpCameraMediaMtxRelay {
  LinuxIpCameraMediaMtxRelay({
    this.executable = '/opt/hmi/bin/mediamtx',
    this.localHost = '127.0.0.1',
    this.port = 8554,
    MediaMtxConfigWriter? configWriter,
    ProcessSupervisor? supervisor,
  })  : _configWriter = configWriter ?? MediaMtxConfigWriter(),
        _supervisor = supervisor ??
            ProcessSupervisor(
              restartPolicy: const RestartPolicy.onFailure(
                delay: Duration(seconds: 3),
              ),
              logSink: (line) => debugPrint(line),
            );

  final String executable;
  final String localHost;
  final int port;
  final MediaMtxConfigWriter _configWriter;
  final ProcessSupervisor _supervisor;

  IpCameraRelayStatus _status = IpCameraRelayStatus.stopped;
  Future<void>? _ensureInFlight;

  @override
  IpCameraRelayStatus get currentStatus => _status;

  @override
  Uri get localPr0 => Uri(
        scheme: 'rtsp',
        host: localHost,
        port: port,
        path: '/camera/pr0',
      );

  @override
  Uri get localPr1 => Uri(
        scheme: 'rtsp',
        host: localHost,
        port: port,
        path: '/camera/pr1',
      );

  @override
  Future<void> ensureStarted(IpCameraStreams upstream) async {
    final existing = _ensureInFlight;
    if (existing != null) {
      await existing;
      if (_status.phase == IpCameraRelayPhase.running) {
        return;
      }
    }
    final done = Completer<void>();
    _ensureInFlight = done.future;
    try {
      await _ensureStartedBody(upstream);
    } finally {
      _ensureInFlight = null;
      if (!done.isCompleted) {
        done.complete();
      }
    }
  }

  Future<void> _ensureStartedBody(IpCameraStreams upstream) async {
    if (!Platform.isLinux) {
      _status = const IpCameraRelayStatus(
        phase: IpCameraRelayPhase.error,
        detail: 'MediaMTX only on Linux',
      );
      return;
    }
    if (_status.phase != IpCameraRelayPhase.running) {
      _status = const IpCameraRelayStatus(phase: IpCameraRelayPhase.starting);
    }
    try {
      if (_supervisor.isRunning) {
        _status = const IpCameraRelayStatus(phase: IpCameraRelayPhase.running);
        return;
      }

      final exeFile = File(executable);
      if (!await exeFile.exists()) {
        _status = IpCameraRelayStatus(
          phase: IpCameraRelayPhase.error,
          detail: 'mediamtx missing at $executable (make build-app)',
        );
        return;
      }

      final host = upstream.pr0.host;
      final cfg = await _configWriter.write(cameraHost: host);
      await _supervisor.start(
        executable: executable,
        arguments: <String>[cfg.path],
        workingDirectory: File(executable).parent.path,
        logPrefix: 'mediamtx',
      );

      // Brief settle: child must still be alive.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!_supervisor.isRunning) {
        _status = const IpCameraRelayStatus(
          phase: IpCameraRelayPhase.error,
          detail: 'mediamtx exited immediately',
        );
        return;
      }
      _status = const IpCameraRelayStatus(phase: IpCameraRelayPhase.running);
    } catch (e) {
      debugPrint('ip_camera mediamtx ensure failed: $e');
      _status = IpCameraRelayStatus(
        phase: IpCameraRelayPhase.error,
        detail: '$e',
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _supervisor.stop();
    } catch (e) {
      debugPrint('ip_camera mediamtx stop failed: $e');
    }
    _status = IpCameraRelayStatus.stopped;
  }
}

final class StubIpCameraMediaMtxRelay implements IpCameraMediaMtxRelay {
  StubIpCameraMediaMtxRelay({
    this.failStart = false,
    this.startDelay = Duration.zero,
  });

  final bool failStart;
  final Duration startDelay;
  IpCameraRelayStatus _status = IpCameraRelayStatus.stopped;

  @override
  IpCameraRelayStatus get currentStatus => _status;

  @override
  Uri get localPr0 => Uri.parse('rtsp://127.0.0.1:8554/camera/pr0');

  @override
  Uri get localPr1 => Uri.parse('rtsp://127.0.0.1:8554/camera/pr1');

  @override
  Future<void> ensureStarted(IpCameraStreams upstream) async {
    if (failStart) {
      _status = const IpCameraRelayStatus(
        phase: IpCameraRelayPhase.error,
        detail: 'stub fail',
      );
      return;
    }
    _status = const IpCameraRelayStatus(phase: IpCameraRelayPhase.starting);
    if (startDelay > Duration.zero) {
      await Future<void>.delayed(startDelay);
    }
    _status = const IpCameraRelayStatus(phase: IpCameraRelayPhase.running);
  }

  @override
  Future<void> stop() async {
    _status = IpCameraRelayStatus.stopped;
  }
}
