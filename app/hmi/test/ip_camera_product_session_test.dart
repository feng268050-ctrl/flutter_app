import 'dart:async';

import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';

class _FakeEth implements EthernetController {
  final _link = StreamController<EthLinkState>.broadcast();
  EthLinkState _currentLink = const EthLinkState(phase: EthLinkPhase.up);

  void emitLink(EthLinkPhase phase) {
    _currentLink = EthLinkState(phase: phase);
    _link.add(_currentLink);
  }

  @override
  String get interfaceName => 'eth0';

  @override
  Stream<EthAdminState> get admin => const Stream.empty();

  @override
  Stream<EthLinkState> get link => _link.stream;

  @override
  EthAdminState get currentAdmin => EthAdminState.on;

  @override
  EthLinkState get currentLink => _currentLink;

  @override
  Future<void> setInterfaceEnabled(bool enabled) async {}

  @override
  Future<EthIpv4Config> getIpv4Config() async => EthIpv4Config.dhcpDefault;

  @override
  Future<void> setIpv4Config(EthIpv4Config config) async {}

  @override
  Future<EthLinkState> linkDetails() async => currentLink;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() => _link.close();
}

class _CountingPath implements IpCameraEth0Path {
  int calls = 0;

  @override
  Future<IpCameraEth0ConfigureResult> configure({
    required String cameraIp,
    String? wlanIp,
  }) async {
    calls++;
    return const IpCameraEth0ConfigureResult(ok: true, pingOk: true);
  }
}

class _FakeWifi implements WifiController {
  @override
  Stream<WifiRadioState> get radio => const Stream.empty();

  @override
  Stream<WifiConnectionState> get connection => const Stream.empty();

  @override
  String get interfaceName => 'wlan0';

  @override
  WifiRadioState get currentRadio => WifiRadioState.off;

  @override
  WifiConnectionState get currentConnection => WifiConnectionState.disconnected;

  @override
  Future<void> setRadioEnabled(bool enabled) async {}

  @override
  Future<List<WifiAccessPoint>> scan(
          {Duration timeout = const Duration(seconds: 8)}) async =>
      const [];

  @override
  Future<void> connect({
    required String ssid,
    String? psk,
    String? bssid,
    bool hidden = false,
    bool requiresPsk = false,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> forget(String ssid) async {}

  @override
  Future<List<WifiSavedNetwork>> savedNetworks() async => const [];

  @override
  Future<WlanIpv4Config> getIpv4Config() async => WlanIpv4Config.dhcpDefault;

  @override
  Future<void> setIpv4Config(WlanIpv4Config config) async {}

  @override
  Future<WifiConnectionState> linkDetails() async => currentConnection;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
      'session reaches connected with healthy camera + path; preview falls back when relay fails',
      () async {
    var ok = false;
    final linuxCam = LinuxIpCameraController(
      cameraHost: '192.168.1.100',
      recoveryStablePings: 1,
      probe: (_) async => ok,
    );
    final session = IpCameraProductSession(
      camera: linuxCam,
      ethernet: _FakeEth(),
      wifi: _FakeWifi(),
      eth0Path: StubIpCameraEth0Path(ok: true, pingOk: true),
      relay: StubIpCameraMediaMtxRelay(failStart: true),
      attemptBudget: 3,
      eventDebounce: Duration.zero,
      failedRetryInterval: const Duration(days: 1),
    );

    ok = true;
    final done = session.status.firstWhere(
      (s) => s.phase == IpCameraUiPhase.connected,
    );
    await session.start();
    expect(
      await done.timeout(const Duration(seconds: 5)),
      isA<IpCameraUiStatus>(),
    );
    expect(session.currentStatus.phase, IpCameraUiPhase.connected);
    // Relay stub failed → preview falls back to native camera RTSP.
    expect(session.previewPr1?.toString(), 'rtsp://192.168.1.100/PR1');
    expect(session.previewPr0?.toString(), 'rtsp://192.168.1.100/PR0');
    expect(session.relayStatus.phase, IpCameraRelayPhase.error);
    expect(session.previewReady, isTrue);

    await session.dispose();
  });

  test('preview binds localhost MediaMTX when relay is running', () async {
    final cam = LinuxIpCameraController(
      cameraHost: '192.168.1.100',
      recoveryStablePings: 1,
      probe: (_) async => true,
    );
    final session = IpCameraProductSession(
      camera: cam,
      ethernet: _FakeEth(),
      wifi: _FakeWifi(),
      eth0Path: StubIpCameraEth0Path(ok: true, pingOk: true),
      relay: StubIpCameraMediaMtxRelay(),
      eventDebounce: Duration.zero,
      failedRetryInterval: const Duration(days: 1),
    );

    await session.start();
    expect(session.currentStatus.phase, IpCameraUiPhase.connected);
    expect(session.relayStatus.phase, IpCameraRelayPhase.running);
    expect(session.previewPr1?.toString(), 'rtsp://127.0.0.1:8554/camera/pr1');
    expect(session.previewPr0?.toString(), 'rtsp://127.0.0.1:8554/camera/pr0');
    expect(session.previewReady, isTrue);

    await session.dispose();
  });

  test('exhausted attempts become failed', () async {
    final cam = LinuxIpCameraController(
      cameraHost: '192.168.1.100',
      recoveryStablePings: 1,
      probe: (_) async => false,
    );
    final session = IpCameraProductSession(
      camera: cam,
      ethernet: _FakeEth(),
      wifi: _FakeWifi(),
      eth0Path: StubIpCameraEth0Path(ok: false),
      relay: StubIpCameraMediaMtxRelay(),
      attemptBudget: 2,
      eventDebounce: Duration.zero,
      failedRetryInterval: const Duration(days: 1),
    );

    final failed = session.status.firstWhere(
      (s) => s.phase == IpCameraUiPhase.failed,
    );
    await session.start();
    expect(
      await failed.timeout(const Duration(seconds: 5)),
      isA<IpCameraUiStatus>(),
    );
    await session.dispose();
  });

  test('self-generated configuring/up events do not reconfigure in a loop',
      () async {
    final eth = _FakeEth();
    final path = _CountingPath();
    final cam = LinuxIpCameraController(
      cameraHost: '192.168.1.100',
      recoveryStablePings: 1,
      probe: (_) async => true,
    );
    final session = IpCameraProductSession(
      camera: cam,
      ethernet: eth,
      wifi: _FakeWifi(),
      eth0Path: path,
      relay: StubIpCameraMediaMtxRelay(),
      eventDebounce: const Duration(milliseconds: 10),
      failedRetryInterval: const Duration(days: 1),
    );

    await session.start();
    expect(path.calls, 1);

    eth.emitLink(EthLinkPhase.configuring);
    eth.emitLink(EthLinkPhase.up);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(path.calls, 1);

    eth.emitLink(EthLinkPhase.noCarrier);
    eth.emitLink(EthLinkPhase.up);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(path.calls, 2);

    await session.dispose();
    await eth.dispose();
  });
}
