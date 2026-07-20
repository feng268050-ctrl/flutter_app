import 'dart:async';

import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/device_sn_reader.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';

class _FakeSnReader extends DeviceSnReader {
  const _FakeSnReader() : super();

  @override
  Future<String> read() async => 'test-sn';
}

final _demoSysInfo = StubSysInfo(
  snapshotData: const SysInfoSnapshot(
    serialNumber: 'test-sn',
    kernelRelease: '6.1.0-test',
    appVersion: kSystemVersion,
    thermal: [
      ThermalZone(
        id: 'thermal_zone0',
        type: 'soc-thermal',
        temperatureCelsius: 42.5,
      ),
      ThermalZone(
        id: 'thermal_zone1',
        type: 'gpu-thermal',
        temperatureCelsius: 39.0,
      ),
    ],
  ),
);

class _OfflineModbus extends ModbusRtuClient {
  _OfflineModbus() : super();

  @override
  Future<bool> open() async => false;

  @override
  Future<void> startLiveDemo({
    required void Function(List<ModbusAttributeChange> changes) onAttributeChanges,
    void Function(ModbusHealth health)? onHealth,
    Iterable<String>? watchIds,
  }) async {
    // Host widget tests: no serial — leave Demo tiles at `-`.
  }

  @override
  Future<ModbusDeviceInfoSnapshot> readDeviceInfo() async {
    return ModbusDeviceInfoSnapshot.unavailable;
  }

  @override
  Future<ModbusAlarmTemperaturesSnapshot> readAlarmTemperatures() async {
    return ModbusAlarmTemperaturesSnapshot.unavailable;
  }
}

/// Avoid LinuxBluez dispose → Process.run timers under fake_async.
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

Finder _mainScrollable() => find.byType(Scrollable).first;

/// Labels below the fold are offstage; ListView still builds them.
Finder _textAnywhere(String text) => find.text(text, skipOffstage: false);

void main() {
  testWidgets('shows P2 device information labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: P2DemoPage(
          deviceSnReader: const _FakeSnReader(),
          sysInfo: _demoSysInfo,
          modbusClient: _OfflineModbus(),
          bluetoothController: _NoopBluetooth(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Device SN'), findsOneWidget);
    expect(find.text('Gunhead SN'), findsOneWidget);
    expect(_textAnywhere('System Version'), findsOneWidget);
    expect(_textAnywhere('Kernel Version'), findsOneWidget);
    expect(_textAnywhere('Control Card Version'), findsOneWidget);
    expect(_textAnywhere(kSystemVersion), findsOneWidget);
    expect(_textAnywhere('6.1.0-test'), findsOneWidget);
    expect(find.text(kUnavailableDisplay), findsWidgets);
    expect(find.text('Modbus Link'), findsOneWidget);
    expect(find.text('Alarm Information'), findsOneWidget);
    expect(_textAnywhere('Pump Comm Status'), findsOneWidget);
    expect(_textAnywhere('Gun Comm Status'), findsOneWidget);
    expect(_textAnywhere('Feeder Comm Status'), findsOneWidget);
    // Temperatures moved to Home translucent card.
    expect(find.text('SoC Temperature', skipOffstage: false), findsNothing);
    expect(find.text('GPU Temperature', skipOffstage: false), findsNothing);

    await tester.scrollUntilVisible(
      _textAnywhere('Debug'),
      300,
      scrollable: _mainScrollable(),
    );
    expect(_textAnywhere('Debug'), findsOneWidget);

    // RGB LED moved to Settings → Display & Sound.
    expect(find.text('RGB LED', skipOffstage: false), findsNothing);
  });

  testWidgets('app demo shows Device Information title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: P2DemoPage(
          deviceSnReader: const _FakeSnReader(),
          sysInfo: _demoSysInfo,
          modbusClient: _OfflineModbus(),
          bluetoothController: _NoopBluetooth(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Device Information'), findsOneWidget);
  });
}
