import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/foundation.dart';

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
    this.renderHelper = '/usr/libexec/hmi/render-mediamtx-config.sh',
    this.unit = 'mediamtx.service',
    this.localHost = '127.0.0.1',
    this.port = 8554,
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) : _run = run ?? ((exe, args) => Process.run(exe, args));

  final String renderHelper;
  final String unit;
  final String localHost;
  final int port;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

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
      final host = upstream.pr0.host;
      await _run(renderHelper, <String>[host]);

      // If systemd already has the unit, skip start (avoids queued job stalls).
      final already = await _isActive();
      if (!already) {
        final start = await _run('systemctl', <String>['start', unit]);
        if (start.exitCode != 0) {
          _status = IpCameraRelayStatus(
            phase: IpCameraRelayPhase.error,
            detail: 'systemctl start failed (${start.exitCode})',
          );
          return;
        }
      }

      final activeOut = await _activeState();
      if (activeOut != 'active') {
        _status = IpCameraRelayStatus(
          phase: IpCameraRelayPhase.error,
          detail: 'mediamtx not active ($activeOut)',
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

  Future<bool> _isActive() async {
    return (await _activeState()) == 'active';
  }

  Future<String> _activeState() async {
    final active = await _run('systemctl', <String>['is-active', unit]);
    return active.stdout.toString().trim();
  }

  @override
  Future<void> stop() async {
    if (!Platform.isLinux) {
      _status = IpCameraRelayStatus.stopped;
      return;
    }
    try {
      await _run('systemctl', <String>['stop', unit]);
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
