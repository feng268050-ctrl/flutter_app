import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/device_sn_reader.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_boot_marker.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_coordinator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/os_paths.dart';

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
  Future<void> ensurePolling() async {}

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();

  @override
  Future<Stream<ModbusHealth>> watchHealth() async => const Stream.empty();

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
      ),
    ),
    modbusClient: _OfflineModbus(),
    bluetoothController: _NoopBluetooth(),
  );
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('boot-sc-gate-');
    BootSelfCheckBootMarker.pathOverrideForTest =
        '${dir.path}/boot-self-check-done';
    BootSelfCheckCoordinator.resetForTest();
  });

  tearDown(() async {
    BootSelfCheckCoordinator.resetForTest();
    BootSelfCheckBootMarker.resetForTest();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  group('BootSelfCheckBootMarker', () {
    test('default path uses OsPaths.runHmi', () {
      BootSelfCheckBootMarker.pathOverrideForTest = null;
      expect(
        BootSelfCheckBootMarker.path,
        '${OsPaths.runHmi}/${BootSelfCheckBootMarker.fileName}',
      );
      BootSelfCheckBootMarker.pathOverrideForTest =
          '${dir.path}/boot-self-check-done';
    });

    test('mark creates file; exists reflects it', () {
      expect(BootSelfCheckBootMarker.exists(), isFalse);
      BootSelfCheckBootMarker.mark();
      expect(BootSelfCheckBootMarker.exists(), isTrue);
      expect(File(BootSelfCheckBootMarker.path).existsSync(), isTrue);
    });
  });

  group('BootSelfCheckGate', () {
    test('shouldSkip false until marked', () {
      expect(BootSelfCheckGate.shouldSkip, isFalse);
      expect(BootSelfCheckGate.hasCompletedThisBoot, isFalse);
      expect(BootSelfCheckGate.isCompletedInProcess, isFalse);
    });

    test('markCompletedInProcess sets process + boot marker', () {
      BootSelfCheckGate.markCompletedInProcess();
      expect(BootSelfCheckGate.isCompletedInProcess, isTrue);
      expect(BootSelfCheckGate.hasCompletedThisBoot, isTrue);
      expect(BootSelfCheckGate.shouldSkip, isTrue);
      expect(BootSelfCheckGate.isActive, isFalse);
    });

    test('reset in-process only keeps boot marker (simulates HMI restart)', () {
      BootSelfCheckGate.markCompletedInProcess();
      BootSelfCheckGate.resetForTest(clearBootMarker: false);

      expect(BootSelfCheckGate.isCompletedInProcess, isFalse);
      expect(BootSelfCheckGate.hasCompletedThisBoot, isTrue);
      expect(BootSelfCheckGate.shouldSkip, isTrue);
    });

    test('full reset clears marker', () {
      BootSelfCheckGate.markCompletedInProcess();
      BootSelfCheckGate.resetForTest();
      expect(BootSelfCheckGate.shouldSkip, isFalse);
      expect(BootSelfCheckGate.hasCompletedThisBoot, isFalse);
    });
  });

  group('BootSelfCheckCoordinator once-per-boot', () {
    testWidgets(
      'boot marker present → second process start skips without dialog',
      (tester) async {
        BootSelfCheckBootMarker.mark();
        BootSelfCheckCoordinator.resetForTest(clearBootMarker: false);

        var completed = false;
        final services = _testServices();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  BootSelfCheckCoordinator.startWhenHomeEntered(
                    context: context,
                    services: services,
                    settings:
                        BootSelfCheckSettings(enabledOverrideForTest: true),
                    onComplete: () => completed = true,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(completed, isTrue);
        expect(BootSelfCheckCoordinator.isRunning, isFalse);
        expect(find.text('Startup Self-Check'), findsNothing);
        expect(BootSelfCheckGate.isCompletedInProcess, isTrue);
      },
    );

    testWidgets(
      'preference disabled marks boot consumed; later enabled still skips',
      (tester) async {
        var completed = false;
        final services = _testServices();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  BootSelfCheckCoordinator.startWhenHomeEntered(
                    context: context,
                    services: services,
                    settings:
                        BootSelfCheckSettings(enabledOverrideForTest: false),
                    onComplete: () => completed = true,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(completed, isTrue);
        expect(BootSelfCheckGate.hasCompletedThisBoot, isTrue);
        expect(find.text('Startup Self-Check'), findsNothing);

        BootSelfCheckCoordinator.resetForTest(clearBootMarker: false);
        completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  BootSelfCheckCoordinator.startWhenHomeEntered(
                    context: context,
                    services: services,
                    settings:
                        BootSelfCheckSettings(enabledOverrideForTest: true),
                    onComplete: () => completed = true,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(completed, isTrue);
        expect(find.text('Startup Self-Check'), findsNothing);
        expect(BootSelfCheckCoordinator.isRunning, isFalse);
      },
    );

    test('missing marker does not skip (shouldSkip false)', () {
      expect(BootSelfCheckBootMarker.exists(), isFalse);
      expect(BootSelfCheckGate.shouldSkip, isFalse);
    });
  });
}
