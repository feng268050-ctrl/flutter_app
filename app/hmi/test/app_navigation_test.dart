import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/device_sn_reader.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_boot_marker.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_coordinator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/features/home/presentation/home_page.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/features/system_status/presentation/system_status_card.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';

class _FakeSnReader extends DeviceSnReader {
  const _FakeSnReader() : super();

  @override
  Future<String> read() async => 'test-sn';
}

class _OfflineModbus extends ModbusRtuClient {
  _OfflineModbus() : super();

  @override
  Future<bool> open() async => false;

  @override
  Future<void> startLiveDemo({
    required void Function(List<ModbusAttributeChange> changes)
        onAttributeChanges,
    void Function(ModbusHealth health)? onHealth,
    Iterable<String>? watchIds,
  }) async {}

  @override
  Future<Object?> readAttribute(String id) async => null;
}

class _NoopBluetooth implements BluetoothController {
  @override
  String? get lastError => null;

  @override
  Stream<BluetoothAdapterState> get adapterState => const Stream.empty();

  @override
  Stream<BluetoothAdapterInfo> get adapterInfo => const Stream.empty();

  @override
  Stream<List<BluetoothRemoteDevice>> get devices => const Stream.empty();

  @override
  Stream<List<BluetoothRemoteDevice>> get incomingDevices => devices;

  @override
  List<BluetoothRemoteDevice> get currentIncomingDevices => const [];

  @override
  Stream<bool> get scanning => const Stream.empty();

  @override
  Stream<BluetoothPairingChallenge?> get pairingChallenge =>
      const Stream.empty();

  @override
  Stream<bool> get a2dpSinkEnabled => const Stream.empty();

  @override
  BluetoothAdapterState get currentAdapterState => BluetoothAdapterState.off;

  @override
  BluetoothAdapterInfo get currentAdapterInfo => const BluetoothAdapterInfo(
        address: '',
        name: '',
        powered: false,
        pairable: false,
      );

  @override
  List<BluetoothRemoteDevice> get currentDevices => const [];

  @override
  bool get currentScanning => false;

  @override
  BluetoothPairingChallenge? get currentPairingChallenge => null;

  @override
  bool get currentA2dpSinkEnabled => false;

  @override
  Future<void> setAdapterEnabled(bool enabled) async {}

  @override
  Future<void> setDiscoverable(bool enabled) async {}

  @override
  Future<void> setPairable(bool enabled) async {}

  @override
  Future<void> setA2dpSinkEnabled(bool enabled) async {}

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> pairAndConnect(String address) async {}

  @override
  Future<void> cancelPairing() async {}

  @override
  Future<void> disconnectRemote(String address) async {}

  @override
  Future<void> removeRemote(String address) async {}

  @override
  Future<void> respondToPairingChallenge(
    String challengeId, {
    required bool accept,
    int? passkey,
    String? pinCode,
  }) async {}

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() async {}
}

BoardProfile _testProfile() => BoardProfile.fromJsonString('''
{
  "board_id": "sim",
  "display_name": "sim",
  "capabilities": ["sysInfo", "datetime", "backlight", "volume", "keyboard", "mouse"],
  "net_roles": {},
  "configs": {},
  "storage_mounts": ["/"],
  "helpers": {}
}
''');

AppServices _testServices() {
  return AppServices(
    boardProfile: _testProfile(),
    deviceSnReader: const _FakeSnReader(),
    sysInfo: StubSysInfo(
      snapshotData: const SysInfoSnapshot(
        serialNumber: 'test-sn',
        kernelRelease: '6.1.0-test',
        appVersion: kSystemVersion,
        memoryTotalBytes: 512 * 1024 * 1024,
        memoryAvailableBytes: 256 * 1024 * 1024,
        uptime: Duration(hours: 2, minutes: 15),
        loadAverage: LoadAverage(one: 0.42, five: 0.3, fifteen: 0.2),
        uiFps: 56,
        rasterFps: 55,
        panelRefreshHz: 56,
        thermal: [
          ThermalZone(
            id: 'thermal_zone0',
            type: 'soc-thermal',
            temperatureCelsius: 48,
          ),
          ThermalZone(
            id: 'thermal_zone1',
            type: 'gpu-thermal',
            temperatureCelsius: 45,
          ),
        ],
      ),
    ),
    modbusClient: _OfflineModbus(),
    bluetoothController: _NoopBluetooth(),
  );
}

Future<void> _openMonitorAlarmTab(WidgetTester tester) async {
  await tester.drag(find.byType(TabBar), const Offset(-320, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('monitor-tab-alarm-information')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late Directory markerDir;

  setUp(() async {
    markerDir = await Directory.systemTemp.createTemp('boot-sc-marker-');
    BootSelfCheckBootMarker.pathOverrideForTest =
        '${markerDir.path}/boot-self-check-done';
    BootSelfCheckCoordinator.resetForTest();
  });

  tearDown(() async {
    BootSelfCheckCoordinator.resetForTest();
    BootSelfCheckBootMarker.resetForTest();
    if (markerDir.existsSync()) {
      await markerDir.delete(recursive: true);
    }
  });

  BootSelfCheckSettings disabledBootCheck() =>
      BootSelfCheckSettings(enabledOverrideForTest: false);

  testWidgets('initial route is product Home with Settings entry', (tester) async {
    await tester.pumpWidget(
      LwsHmiApp(
        boardProfile: _testProfile(),
        services: _testServices(),
        bootSelfCheckSettings: disabledBootCheck(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(const ValueKey('home-clock-text')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('AI Vision'), findsOneWidget);
    // Temperatures live on Monitor → Alarm Information (not Home).
    expect(find.text('Temperatures'), findsNothing);
    // No primary Demo entry on Home.
    expect(find.text('Demo'), findsNothing);
    expect(find.text('Device Information'), findsNothing);
    // Self-check is an overlay, not a named initial route.
    expect(find.text('Startup Self-Check'), findsNothing);
  });

  testWidgets('Monitor entry navigates to Monitor page', (tester) async {
    await tester.pumpWidget(
      LwsHmiApp(
        boardProfile: _testProfile(),
        services: _testServices(),
        bootSelfCheckSettings: disabledBootCheck(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Monitor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Work Information'), findsWidgets);
    expect(find.text('Machine Status'), findsWidgets);
    expect(find.text('Alarm Information'), findsWidgets);
    expect(find.text('Videos'), findsWidgets);
    expect(find.text('AI Vision'), findsWidgets);

    await _openMonitorAlarmTab(tester);

    expect(find.text('Motor Temperature'), findsOneWidget);
    expect(find.text('Alarm Logs'), findsOneWidget);
    expect(find.text('Welding Gun'), findsOneWidget);
  });

  testWidgets('named /monitor route resolves', (tester) async {
    await tester.pumpWidget(
      LwsHmiApp(
        boardProfile: _testProfile(),
        services: _testServices(),
        bootSelfCheckSettings: disabledBootCheck(),
      ),
    );
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed(AppRoutes.monitor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Work Information'), findsWidgets);
    expect(find.text('Weld Time Ratio'), findsOneWidget);
    await _openMonitorAlarmTab(tester);

    expect(find.text('Motor Temperature'), findsOneWidget);
  });

  testWidgets('Settings route shows four tabs and Bluetooth entry', (tester) async {
    final services = _testServices();
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Device Information'), findsWidgets);
    expect(find.text('Common Settings'), findsOneWidget);
    expect(find.text('Advanced Settings'), findsOneWidget);
    expect(find.text('Custom Home Page'), findsOneWidget);

    await tester.tap(find.text('Common Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('Wireless Network'), findsOneWidget);
    expect(find.text('Screen Brightness'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('RGB LED'), findsOneWidget);
    expect(find.text('Debug over USB'), findsNothing);
    expect(find.text('Debug over LAN'), findsNothing);
  });

  testWidgets('named /demo route resolves', (tester) async {
    await tester.pumpWidget(
      LwsHmiApp(
        boardProfile: _testProfile(),
        services: _testServices(),
        bootSelfCheckSettings: disabledBootCheck(),
      ),
    );
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.demo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Device Information'), findsOneWidget);
    expect(find.text('RGB LED', skipOffstage: false), findsNothing);
    expect(find.text('Debug', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Home paints with self-check overlay when enabled', (tester) async {
    await tester.pumpWidget(
      LwsHmiApp(
        boardProfile: _testProfile(),
        services: _testServices(),
        bootSelfCheckSettings: BootSelfCheckSettings(
          enabledOverrideForTest: true,
        ),
      ),
    );
    await tester.pump();
    // Pipeline: 9 items × ≥280ms dwell + Modbus soft-fail.
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Startup Self-Check'), findsOneWidget);
    // Footer appears after all items reach a terminal status.
    expect(find.text('Don’t show again'), findsOneWidget);

    // Drain auto-dismiss timer so the binding ends clean.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('system status overlay hidden by default', (tester) async {
    await tester.pumpWidget(
      LwsHmiApp(
        boardProfile: _testProfile(),
        services: _testServices(),
        bootSelfCheckSettings: disabledBootCheck(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SystemStatusCard), findsNothing);
  });
}
