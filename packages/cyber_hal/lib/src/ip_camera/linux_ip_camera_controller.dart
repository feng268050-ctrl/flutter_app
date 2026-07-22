import 'dart:async';

import 'package:cyber_hal/src/ip_camera/ip_camera_controller.dart';
import 'package:cyber_hal/src/ip_camera/ip_camera_models.dart';
import 'package:cyber_hal/src/ip_camera/ip_camera_probes.dart';
import 'package:cyber_hal/src/ip_camera/ip_camera_recording.dart';
import 'package:cyber_hal/src/ip_camera/linux_ip_camera_recorder.dart';
import 'package:flutter/foundation.dart';

/// Linux [IpCameraController]: HAL-owned health (path-agnostic).
///
/// Reachability of [cameraHost] may be via eth0, wlan0, or any routed path —
/// this type only probes the given host. Default Linux probe is a short TCP
/// connect to the RTSP port ([tcpRtspPortProbe]); inject [icmpIpCameraProbe],
/// [rtspOptionsProbe], or [relayInformedProbe] when needed. MUST NOT SETUP/PLAY
/// `/PR0`/`/PR1`. MediaMTX / dedicated-link bring-up belong in the product App.
final class LinuxIpCameraController implements IpCameraController {
  LinuxIpCameraController({
    required String cameraHost,
    IpCameraStreamPaths streamPaths = const IpCameraStreamPaths.pr01(),
    IpCameraProbe? probe,
    IpCameraRecordingController? recording,
    this.recoveryStablePings = 3,
    this.failureStablePings = 3,
    this.postConfigureQuiet = const Duration(seconds: 5),
    this.probeInterval = const Duration(seconds: 1),
    this.probeTimeout = const Duration(seconds: 2),
  })  : cameraHost = cameraHost.trim(),
        streams = IpCameraStreams.fromHost(
          cameraHost.trim(),
          paths: streamPaths,
        ),
        recording = recording ?? LinuxIpCameraRecordingController(),
        // Locked default after device ladder (see openspec camera-health-probe-ladder):
        // TCP :554 short-connect — ICMP/OPTIONS remain injectable.
        _probe = probe ?? tcpRtspPortProbe() {
    if (this.cameraHost.isEmpty) {
      throw ArgumentError.value(cameraHost, 'cameraHost', 'must be non-empty');
    }
  }

  @override
  final String cameraHost;

  @override
  final IpCameraStreams streams;

  @override
  final IpCameraRecordingController recording;

  /// Consecutive OK probes required before [IpCameraHealthPhase.healthy].
  final int recoveryStablePings;

  /// Consecutive failed probes required before declaring the camera unhealthy.
  /// This prevents a single lost ICMP packet from tearing down product relays.
  final int failureStablePings;

  /// Ignore probe failures for this long after [resumeProbes].
  final Duration postConfigureQuiet;

  final Duration probeInterval;
  final Duration probeTimeout;

  final IpCameraProbe _probe;

  final _healthCtrl = StreamController<IpCameraHealth>.broadcast();

  IpCameraHealth _health = IpCameraHealth(
    phase: IpCameraHealthPhase.unknown,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Timer? _timer;
  bool _monitoring = false;
  bool _disposed = false;
  bool _probeInFlight = false;
  int _suspendDepth = 0;
  DateTime? _quietUntil;
  bool _reachableAtSuspend = false;
  int _consecutiveOk = 0;
  int _consecutiveFail = 0;

  @override
  Stream<IpCameraHealth> get health => _healthCtrl.stream;

  @override
  IpCameraHealth get currentHealth => _health;

  bool get isSuspended => _suspendDepth > 0;

  @override
  Future<void> startMonitoring() async {
    _ensureNotDisposed();
    if (_monitoring) {
      return;
    }
    _monitoring = true;
    _timer?.cancel();
    _timer = Timer.periodic(probeInterval, (_) {
      unawaited(probeOnce());
    });
    await probeOnce();
  }

  @override
  Future<IpCameraHealth> probeOnce() async {
    _ensureNotDisposed();
    if (_suspendDepth > 0) {
      return _health;
    }
    if (_probeInFlight) {
      return _health;
    }
    _probeInFlight = true;
    try {
      final ok = await _probe(cameraHost).timeout(
        probeTimeout,
        onTimeout: () => false,
      );
      _onProbeResult(ok);
    } catch (e) {
      debugPrint('ip_camera: probe error host=$cameraHost: $e');
      _onProbeResult(false);
    } finally {
      _probeInFlight = false;
    }
    return _health;
  }

  @override
  void suspendProbes() {
    _ensureNotDisposed();
    if (_suspendDepth == 0) {
      _reachableAtSuspend = _health.phase == IpCameraHealthPhase.healthy;
    }
    _suspendDepth++;
  }

  @override
  void resumeProbes({bool? configurePingOk}) {
    _ensureNotDisposed();
    if (_suspendDepth <= 0) {
      _suspendDepth = 0;
      return;
    }
    _suspendDepth--;
    if (_suspendDepth > 0) {
      return;
    }
    _quietUntil = DateTime.now().add(postConfigureQuiet);
    if (configurePingOk == true) {
      _onProbeResult(true);
    } else if (configurePingOk == false && !_reachableAtSuspend) {
      _consecutiveOk = 0;
    }
    // If configurePingOk is false but was healthy at suspend, keep health
    // (lws-ui: failed configure ping does not downgrade previously healthy).
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _monitoring = false;
    _timer?.cancel();
    _timer = null;
    await recording.dispose();
    await _healthCtrl.close();
  }

  void _onProbeResult(bool pingOk) {
    if (_suspendDepth > 0) {
      return;
    }
    if (!pingOk && _isQuietActive()) {
      return;
    }

    final wasHealthy = _health.phase == IpCameraHealthPhase.healthy;
    if (pingOk) {
      _consecutiveFail = 0;
      if (wasHealthy) {
        _consecutiveOk = 0;
        _emitCountersOnly();
        return;
      }
      _consecutiveOk++;
      if (_consecutiveOk >= recoveryStablePings) {
        _consecutiveOk = 0;
        _commit(IpCameraHealthPhase.healthy);
      } else {
        _emitCountersOnly();
      }
    } else {
      _consecutiveOk = 0;
      _consecutiveFail++;
      if (!wasHealthy && _health.phase == IpCameraHealthPhase.unhealthy) {
        _emitCountersOnly();
        return;
      }
      if (_consecutiveFail >= failureStablePings) {
        _commit(IpCameraHealthPhase.unhealthy, detail: 'unreachable');
      } else {
        _emitCountersOnly();
      }
    }
  }

  bool _isQuietActive() {
    final until = _quietUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _emitCountersOnly() {
    _emit(
      _health.copyWith(
        consecutiveOk: _consecutiveOk,
        consecutiveFail: _consecutiveFail,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _commit(IpCameraHealthPhase phase, {String? detail}) {
    _emit(
      IpCameraHealth(
        phase: phase,
        consecutiveOk: _consecutiveOk,
        consecutiveFail: _consecutiveFail,
        detail: detail,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _emit(IpCameraHealth next) {
    if (_disposed || _healthCtrl.isClosed) {
      return;
    }
    if (next == _health &&
        next.updatedAt.difference(_health.updatedAt).inMilliseconds.abs() < 1) {
      return;
    }
    // Always emit on phase change; also emit counter-only updates when phase same
    // but consecutive counters changed (tests / diagnostics). Avoid spam: only
    // notify listeners when phase or detail changes OR first unknown→*.
    final phaseChanged = next.phase != _health.phase;
    final detailChanged = next.detail != _health.detail;
    _health = next;
    if (phaseChanged || detailChanged) {
      _healthCtrl.add(next);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('IpCameraController disposed');
    }
  }
}
