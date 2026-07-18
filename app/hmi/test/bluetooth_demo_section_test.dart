import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/ui/demo/bluetooth_demo_section.dart';

class _FakeBtController implements BluetoothController {
  final _stateCtrl = StreamController<BluetoothAdapterState>.broadcast();
  final _infoCtrl = StreamController<BluetoothAdapterInfo>.broadcast();
  final _devicesCtrl =
      StreamController<List<BluetoothRemoteDevice>>.broadcast();
  final _scanCtrl = StreamController<bool>.broadcast();
  final _challengeCtrl =
      StreamController<BluetoothPairingChallenge?>.broadcast(sync: true);
  final _a2dpCtrl = StreamController<bool>.broadcast();

  BluetoothAdapterState _state = BluetoothAdapterState.on;
  BluetoothAdapterInfo _info = const BluetoothAdapterInfo(
    address: 'B4:04:29:B0:5A:FA',
    name: 'hmi',
    powered: true,
    pairable: true,
  );
  List<BluetoothRemoteDevice> _devices = const [
    BluetoothRemoteDevice(
      address: '11:22:33:44:55:66',
      name: 'Demo Keyboard',
      discovered: true,
      kind: BluetoothDeviceKind.keyboard,
      rssi: -50,
    ),
  ];
  bool _scanning = false;
  BluetoothPairingChallenge? _challenge;
  bool _a2dp = false;

  @override
  String? get lastError => null;

  @override
  Stream<BluetoothAdapterState> get adapterState => _stateCtrl.stream;

  @override
  Stream<BluetoothAdapterInfo> get adapterInfo => _infoCtrl.stream;

  @override
  Stream<List<BluetoothRemoteDevice>> get devices => _devicesCtrl.stream;

  @override
  Stream<List<BluetoothRemoteDevice>> get incomingDevices => devices;

  @override
  List<BluetoothRemoteDevice> get currentIncomingDevices => currentDevices;

  @override
  Stream<bool> get scanning => _scanCtrl.stream;

  @override
  Stream<BluetoothPairingChallenge?> get pairingChallenge =>
      _challengeCtrl.stream;

  @override
  Stream<bool> get a2dpSinkEnabled => _a2dpCtrl.stream;

  @override
  BluetoothAdapterState get currentAdapterState => _state;

  @override
  BluetoothAdapterInfo get currentAdapterInfo => _info;

  @override
  List<BluetoothRemoteDevice> get currentDevices => _devices;

  @override
  bool get currentScanning => _scanning;

  @override
  BluetoothPairingChallenge? get currentPairingChallenge => _challenge;

  @override
  bool get currentA2dpSinkEnabled => _a2dp;

  void emitChallenge(BluetoothPairingChallenge? c) {
    _challenge = c;
    _challengeCtrl.add(c);
  }

  void emitScan(bool v) {
    _scanning = v;
    _scanCtrl.add(v);
  }

  @override
  Future<void> setAdapterEnabled(bool enabled) async {}

  @override
  Future<void> setDiscoverable(bool enabled) async {}

  @override
  Future<void> setPairable(bool enabled) async {}

  @override
  Future<void> setA2dpSinkEnabled(bool enabled) async {}

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    emitScan(true);
  }

  @override
  Future<void> stopScan() async {
    emitScan(false);
  }

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
  Future<void> dispose() async {
    await _stateCtrl.close();
    await _infoCtrl.close();
    await _devicesCtrl.close();
    await _scanCtrl.close();
    await _challengeCtrl.close();
    await _a2dpCtrl.close();
  }
}

void main() {
  testWidgets('Bluetooth Demo shows scan list and passkey', (tester) async {
    final ctrl = _FakeBtController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothDemoSection(controller: ctrl),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Demo Keyboard'), findsOneWidget);

    ctrl.emitChallenge(
      const BluetoothPairingChallenge(
        id: 'c1',
        address: '11:22:33:44:55:66',
        name: 'Demo Keyboard',
        kind: BluetoothPairingChallengeKind.displayPasskey,
        passkey: 123456,
      ),
    );
    await tester.pump();
    expect(find.text('123456'), findsOneWidget);
    expect(find.textContaining('Type this 6-digit passkey'), findsOneWidget);

    final scan = find.text('Scan');
    await tester.ensureVisible(scan);
    await tester.tap(scan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Stop scan'), findsOneWidget);
  });

  testWidgets('Bluetooth Demo shows non-fatal error', (tester) async {
    final ctrl = _FakeBtController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothDemoSection(controller: ctrl),
          ),
        ),
      ),
    );

    // Force error path via pair on fake that throws — override by tapping after
    // injecting error through busy guard is internal; simulate via setState path:
    // call pairAndConnect that we make throw.
    final throwing = _ThrowingScanController();
    addTearDown(throwing.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothDemoSection(controller: throwing),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Scan'));
    await tester.pump();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('stale HID link shows Reconnect only (not Disconnect)', (
    tester,
  ) async {
    final ctrl = _FakeBtController()
      .._devices = const [
        BluetoothRemoteDevice(
          address: 'E9:6E:F0:DC:B3:00',
          name: 'QM002',
          paired: true,
          trusted: true,
          connected: true,
          inputReady: false,
          kind: BluetoothDeviceKind.keyboard,
        ),
      ];
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothDemoSection(controller: ctrl),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('QM002'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(find.text('Disconnect'), findsNothing);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('healthy connected HID shows Disconnect only (not Connect)', (
    tester,
  ) async {
    final ctrl = _FakeBtController()
      .._devices = const [
        BluetoothRemoteDevice(
          address: 'E9:6E:F0:DC:B3:00',
          name: 'QM002',
          paired: true,
          trusted: true,
          connected: true,
          inputReady: true,
          kind: BluetoothDeviceKind.keyboard,
        ),
      ];
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothDemoSection(controller: ctrl),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(find.text('Reconnect'), findsNothing);
  });
}

class _ThrowingScanController extends _FakeBtController {
  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    throw BluetoothOperationException('scan boom');
  }
}
