import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/record_work_toggle.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(ProcessModeToast.resetForTest);

  Future<IpCameraProductSession> connectedSession() async {
    final session = IpCameraProductSession(
      camera: StubIpCameraController(
        cameraHost: '192.168.1.100',
        initialPhase: IpCameraHealthPhase.healthy,
        recording: StubIpCameraRecordingController(
          autoReadyAfter: Duration.zero,
        ),
      ),
      ethernet: _FakeEth(),
      wifi: _FakeWifi(),
      eth0Path: StubIpCameraEth0Path(ok: true, pingOk: true),
      relay: StubIpCameraMediaMtxRelay(),
      attemptBudget: 2,
      eventDebounce: Duration.zero,
      failedRetryInterval: const Duration(days: 1),
    );
    final connected = session.status.firstWhere(
      (s) => s.phase == IpCameraUiPhase.connected,
    );
    await session.start();
    await connected.timeout(const Duration(seconds: 5));
    return session;
  }

  AppServices servicesWith(IpCameraProductSession session) {
    return AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: _IdleModbus(),
      ipCamera: session,
    );
  }

  testWidgets('Record Work toggle arms by default when camera is up',
      (tester) async {
    final session = await connectedSession();
    addTearDown(session.dispose);
    final services = servicesWith(session);
    final device = DeviceControlController(services)..keySwitchOn = true;

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: RecordWorkToggle(
              key: const ValueKey('quick-mode-record-work'),
              deviceControl: device,
              compact: true,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Record Work'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CyberCheckbox && w.value == true,
      ),
      findsOneWidget,
    );
  });
}

final class _IdleModbus extends ModbusRtuClient {
  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async => true;

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}

final class _FakeEth implements EthernetController {
  final _link = StreamController<EthLinkState>.broadcast();

  @override
  String get interfaceName => 'eth0';

  @override
  Stream<EthAdminState> get admin => const Stream.empty();

  @override
  Stream<EthLinkState> get link => _link.stream;

  @override
  EthAdminState get currentAdmin => EthAdminState.on;

  @override
  EthLinkState get currentLink =>
      const EthLinkState(phase: EthLinkPhase.up, ipv4: '192.168.1.234');

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

final class _FakeWifi implements WifiController {
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
