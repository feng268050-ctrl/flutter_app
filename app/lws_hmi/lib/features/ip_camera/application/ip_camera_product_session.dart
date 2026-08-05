import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/device/product_property_defaults.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';

/// Trimmed `camera_ip` from properties.ini, or product default when empty.
String effectiveCameraHost(ProductInfo product) =>
    effectiveCameraIpFromProduct(product);

/// Resolve host from a raw properties.ini value (same rules as [effectiveCameraHost]).
String effectiveCameraHostFromRaw(String? productCameraIp) =>
    effectiveCameraIp(productCameraIp);

/// LWS product façade: one [IpCameraController] + eth0 path + MediaMTX + UI phases.
final class IpCameraProductSession {
  IpCameraProductSession({
    required this.camera,
    required this.ethernet,
    required this.wifi,
    IpCameraEth0Path? eth0Path,
    IpCameraMediaMtxRelay? relay,
    this.attemptBudget = 5,
    this.failedRetryInterval = const Duration(seconds: 30),
    this.eventDebounce = const Duration(milliseconds: 800),
  })  : _eth0Path = eth0Path ??
            (Platform.isLinux
                ? LinuxIpCameraEth0Path(ethernet: ethernet)
                : StubIpCameraEth0Path(ok: false)),
        _relay = relay ??
            (Platform.isLinux
                ? LinuxIpCameraMediaMtxRelay()
                : StubIpCameraMediaMtxRelay());

  /// Build with host from properties.ini; blank host = unconfigured (no invent).
  factory IpCameraProductSession.create({
    required String? productCameraIp,
    required EthernetController ethernet,
    required WifiController wifi,
    IpCameraEth0Path? eth0Path,
    IpCameraMediaMtxRelay? relay,
    IpCameraController? cameraOverride,
    IpCameraProbe? probe,
  }) {
    final host = effectiveCameraHostFromRaw(productCameraIp);
    final camera = cameraOverride ??
        LinuxIpCameraController(
          cameraHost: host,
          recoveryStablePings: 3,
          probe: probe,
        );
    return IpCameraProductSession(
      camera: camera,
      ethernet: ethernet,
      wifi: wifi,
      eth0Path: eth0Path,
      relay: relay,
    );
  }

  final IpCameraController camera;
  final EthernetController ethernet;
  final WifiController wifi;
  final IpCameraEth0Path _eth0Path;
  final IpCameraMediaMtxRelay _relay;
  final int attemptBudget;
  final Duration failedRetryInterval;
  final Duration eventDebounce;

  final _statusCtrl = StreamController<IpCameraUiStatus>.broadcast();
  IpCameraUiStatus _status = IpCameraUiStatus.connecting;

  StreamSubscription<EthLinkState>? _ethSub;
  StreamSubscription<WifiConnectionState>? _wifiSub;
  StreamSubscription<IpCameraHealth>? _healthSub;
  Timer? _debounce;
  Timer? _failedRetry;
  bool _started = false;
  bool _disposed = false;
  bool _configureInFlight = false;
  Future<void>? _configureFuture;
  int _attempt = 0;
  bool _pathReady = false;
  EthLinkPhase? _lastEthPhase;
  bool _ethCarrierWasLost = false;
  String? _lastWlanIp;

  Stream<IpCameraUiStatus> get status => _statusCtrl.stream;

  IpCameraUiStatus get currentStatus => _status;

  /// Local MediaMTX fan-out when relay is running; native upstream only as
  /// fallback if the relay failed (keeps Settings preview usable).
  Uri? get previewPr0 {
    if (_status.phase != IpCameraUiPhase.connected) {
      return null;
    }
    switch (_relay.currentStatus.phase) {
      case IpCameraRelayPhase.running:
        return _relay.localPr0;
      case IpCameraRelayPhase.error:
        return camera.streams.pr0;
      case IpCameraRelayPhase.stopped:
      case IpCameraRelayPhase.starting:
        return null;
    }
  }

  Uri? get previewPr1 {
    if (_status.phase != IpCameraUiPhase.connected) {
      return null;
    }
    switch (_relay.currentStatus.phase) {
      case IpCameraRelayPhase.running:
        return _relay.localPr1;
      case IpCameraRelayPhase.error:
        return camera.streams.pr1;
      case IpCameraRelayPhase.stopped:
      case IpCameraRelayPhase.starting:
        return null;
    }
  }

  IpCameraRelayStatus get relayStatus => _relay.currentStatus;

  /// True when Settings may open the GStreamer texture (relay up, or fallback).
  /// Default preview/record path is PR0; PR1 is reserved for AI.
  bool get previewReady => previewPr0 != null;

  /// Home first frame — idempotent. If already started, waits for any in-flight
  /// configure so callers (e.g. Settings) do not race past a half-ready relay.
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    if (camera.cameraHost.trim().isEmpty) {
      _started = true;
      _emit(const IpCameraUiStatus(
        phase: IpCameraUiPhase.failed,
        attempt: 0,
        detail: 'camera_ip unconfigured',
      ));
      return;
    }
    if (_started) {
      final inFlight = _configureFuture;
      if (inFlight != null) {
        await inFlight;
      }
      return;
    }
    _started = true;
    _emit(IpCameraUiStatus(
      phase: IpCameraUiPhase.connecting,
      attempt: _attempt,
    ));

    _lastEthPhase = ethernet.currentLink.phase;
    _ethSub = ethernet.link.listen(_onEthernetLink);
    _wifiSub = wifi.connection.listen((c) {
      final ip = c.ipv4;
      if (ip != _lastWlanIp) {
        _lastWlanIp = ip;
        _scheduleConfigure('wlan-ip');
      }
    });
    _lastWlanIp = wifi.currentConnection.ipv4;

    _healthSub = camera.health.listen(_onHealth);
    await camera.startMonitoring();
    await ensureReady();
  }

  /// Settings open / explicit ensure.
  Future<void> ensureReady() => _runConfigureCycle(reason: 'ensure');

  Future<void> retryNow() {
    _attempt = 0;
    _emit(IpCameraUiStatus(
      phase: IpCameraUiPhase.connecting,
      attempt: 0,
    ));
    return _runConfigureCycle(reason: 'retry');
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _debounce?.cancel();
    _failedRetry?.cancel();
    await _ethSub?.cancel();
    await _wifiSub?.cancel();
    await _healthSub?.cancel();
    await _relay.stop();
    await camera.dispose();
    await _statusCtrl.close();
  }

  void _scheduleConfigure(String reason) {
    if (_disposed || !_started) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(eventDebounce, () {
      unawaited(_runConfigureCycle(reason: reason));
    });
  }

  void _onEthernetLink(EthLinkState link) {
    final previous = _lastEthPhase;
    _lastEthPhase = link.phase;

    // networkctl reconfigure briefly drops RMII carrier. Ignore flaps while we
    // (or a just-finished cycle) own the eth0 apply path.
    if (_configureInFlight) {
      return;
    }

    final carrierAbsent = link.phase == EthLinkPhase.down ||
        link.phase == EthLinkPhase.noCarrier;
    if (carrierAbsent) {
      _ethCarrierWasLost = true;
      _pathReady = false;
      unawaited(_onPhysicalLinkLost());
      return;
    }

    // Only a real carrier-absent -> carrier-present transition should reconfigure.
    if (_ethCarrierWasLost &&
        previous != link.phase &&
        link.phase != EthLinkPhase.error) {
      _ethCarrierWasLost = false;
      _scheduleConfigure('eth-reconnected');
    }
  }

  Future<void> _runConfigureCycle({required String reason}) async {
    if (_disposed) {
      return;
    }

    // Join an in-flight cycle instead of dropping (Settings used to return
    // early while Home still held _configureInFlight, then never saw relay
    // leave "starting").
    final inFlight = _configureFuture;
    if (inFlight != null) {
      await inFlight;
      if (_disposed) {
        return;
      }
      if (reason == 'ensure' && _relaySettledForPreview) {
        _publish();
        return;
      }
      if (_configureInFlight) {
        return;
      }
    } else if (_configureInFlight) {
      return;
    }

    if (reason == 'ensure' && _relaySettledForPreview) {
      _publish();
      return;
    }

    if (_status.phase == IpCameraUiPhase.failed && reason == 'ensure') {
      // allow ensure from Settings to leave failed
    }
    _configureInFlight = true;
    final done = Completer<void>();
    _configureFuture = done.future;
    _failedRetry?.cancel();
    try {
      while (!_disposed && _attempt < attemptBudget) {
        _attempt++;
        _emit(IpCameraUiStatus(
          phase: IpCameraUiPhase.connecting,
          attempt: _attempt,
          detail: reason,
        ));

        camera.suspendProbes();
        final wlan = wifi.currentConnection.ipv4;
        final path = await _eth0Path.configure(
          cameraIp: camera.cameraHost,
          wlanIp: wlan,
        );
        camera.resumeProbes(configurePingOk: path.pingOk);
        _pathReady = path.ok;

        if (!path.ok) {
          debugPrint('ip_camera: path failed attempt=$_attempt ${path.detail}');
          await Future<void>.delayed(Duration(milliseconds: 350 * _attempt));
          continue;
        }

        // Give health a few probes after path ready.
        for (var i = 0; i < 4; i++) {
          await camera.probeOnce();
          if (camera.currentHealth.isHealthy) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }

        if (camera.currentHealth.isHealthy) {
          _emit(IpCameraUiStatus(
            phase: IpCameraUiPhase.connected,
            attempt: _attempt,
          ));
          _attempt = 0;
          // Await relay so Settings can bind localhost preview after ensureReady.
          await _relay.ensureStarted(camera.streams);
          // Relay phase is not part of IpCameraUiStatus equality — force a
          // rebuild so MediaMTX leaves "starting" and previewReady becomes true.
          _publish();
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * _attempt));
      }

      _emit(IpCameraUiStatus(
        phase: IpCameraUiPhase.failed,
        attempt: _attempt,
        detail: 'attempt budget exhausted',
      ));
      await _relay.stop();
      _scheduleFailedRetry();
    } finally {
      _configureInFlight = false;
      _configureFuture = null;
      if (!done.isCompleted) {
        done.complete();
      }
    }
  }

  bool get _relaySettledForPreview {
    if (_status.phase != IpCameraUiPhase.connected) {
      return false;
    }
    switch (_relay.currentStatus.phase) {
      case IpCameraRelayPhase.running:
      case IpCameraRelayPhase.error:
        return true;
      case IpCameraRelayPhase.stopped:
      case IpCameraRelayPhase.starting:
        return false;
    }
  }

  void _onHealth(IpCameraHealth h) {
    if (_disposed || !_started) {
      return;
    }
    if (_status.phase == IpCameraUiPhase.connected && !h.isHealthy) {
      unawaited(_onLostHealth());
    } else if (_status.phase == IpCameraUiPhase.connecting &&
        h.isHealthy &&
        _pathReady &&
        !_configureInFlight) {
      unawaited(_onBecameHealthy());
    }
  }

  Future<void> _onBecameHealthy() async {
    _emit(const IpCameraUiStatus(phase: IpCameraUiPhase.connected));
    _attempt = 0;
    await _relay.ensureStarted(camera.streams);
    _publish();
  }

  Future<void> _onPhysicalLinkLost() async {
    await _relay.stop();
    _emit(IpCameraUiStatus(
      phase: IpCameraUiPhase.connecting,
      attempt: _attempt,
      detail: 'ethernet disconnected',
    ));
  }

  Future<void> _onLostHealth() async {
    await _relay.stop();
    _emit(IpCameraUiStatus(
      phase: IpCameraUiPhase.connecting,
      attempt: _attempt,
      detail: 'link lost',
    ));
    _scheduleConfigure('health-lost');
  }

  void _scheduleFailedRetry() {
    _failedRetry?.cancel();
    _failedRetry = Timer(failedRetryInterval, () {
      if (_disposed) {
        return;
      }
      _attempt = 0;
      unawaited(_runConfigureCycle(reason: 'slow-retry'));
    });
  }

  void _emit(IpCameraUiStatus next) {
    if (_disposed || _statusCtrl.isClosed) {
      return;
    }
    if (next == _status) {
      return;
    }
    _status = next;
    _statusCtrl.add(next);
  }

  /// Re-push current UI status so listeners re-read [relayStatus] / preview URLs.
  void _publish() {
    if (_disposed || _statusCtrl.isClosed) {
      return;
    }
    _statusCtrl.add(_status);
  }
}
