import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/home_status_bar.dart';
import 'package:lws_hmi/features/home/presentation/wifi_signal_bars.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

class _FakeWifi implements WifiController {
  _FakeWifi({
    this.radioState = WifiRadioState.off,
    WifiConnectionState? connection,
  }) : connectionState = connection ?? WifiConnectionState.disconnected;

  WifiRadioState radioState;
  WifiConnectionState connectionState;

  final _radioCtrl = StreamController<WifiRadioState>.broadcast();
  final _connCtrl = StreamController<WifiConnectionState>.broadcast();

  void emitRadio(WifiRadioState s) {
    radioState = s;
    _radioCtrl.add(s);
  }

  @override
  Stream<WifiRadioState> get radio => _radioCtrl.stream;

  @override
  Stream<WifiConnectionState> get connection => _connCtrl.stream;

  @override
  String get interfaceName => 'wlan0';

  @override
  WifiRadioState get currentRadio => radioState;

  @override
  WifiConnectionState get currentConnection => connectionState;

  @override
  Future<List<WifiAccessPoint>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async =>
      const [];

  @override
  Future<void> setRadioEnabled(bool enabled) async {}

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
  Future<WifiConnectionState> linkDetails() async => connectionState;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() async {
    await _radioCtrl.close();
    await _connCtrl.close();
  }
}

class _FakeBt implements BluetoothController {
  _FakeBt({
    this.adapter = BluetoothAdapterState.off,
    List<BluetoothRemoteDevice>? devices,
    this.challenge,
  }) : devicesList = devices ?? const [];

  BluetoothAdapterState adapter;
  List<BluetoothRemoteDevice> devicesList;
  BluetoothPairingChallenge? challenge;

  final _adapterCtrl = StreamController<BluetoothAdapterState>.broadcast();
  final _devicesCtrl =
      StreamController<List<BluetoothRemoteDevice>>.broadcast();
  final _challengeCtrl =
      StreamController<BluetoothPairingChallenge?>.broadcast();

  @override
  String? get lastError => null;

  @override
  Stream<BluetoothAdapterState> get adapterState => _adapterCtrl.stream;

  @override
  Stream<BluetoothAdapterInfo> get adapterInfo => const Stream.empty();

  @override
  Stream<List<BluetoothRemoteDevice>> get devices => _devicesCtrl.stream;

  @override
  Stream<List<BluetoothRemoteDevice>> get incomingDevices => devices;

  @override
  List<BluetoothRemoteDevice> get currentIncomingDevices => devicesList;

  @override
  Stream<bool> get scanning => const Stream.empty();

  @override
  Stream<BluetoothPairingChallenge?> get pairingChallenge =>
      _challengeCtrl.stream;

  @override
  Stream<bool> get a2dpSinkEnabled => const Stream.empty();

  @override
  BluetoothAdapterState get currentAdapterState => adapter;

  @override
  BluetoothAdapterInfo get currentAdapterInfo => const BluetoothAdapterInfo(
        address: '',
        name: '',
        powered: false,
        pairable: false,
      );

  @override
  List<BluetoothRemoteDevice> get currentDevices => devicesList;

  @override
  bool get currentScanning => false;

  @override
  BluetoothPairingChallenge? get currentPairingChallenge => challenge;

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
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {}

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
  Future<void> dispose() async {
    await _adapterCtrl.close();
    await _devicesCtrl.close();
    await _challengeCtrl.close();
  }
}

Widget _wrap({
  required WifiController wifi,
  required BluetoothController bluetooth,
  IpCameraUiStatus camera = IpCameraUiStatus.connecting,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: HomeStatusBar(
          cameraStatus: camera,
          wifi: wifi,
          bluetooth: bluetooth,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('camera-only when wifi/bt off', (tester) async {
    final wifi = _FakeWifi();
    final bt = _FakeBt();
    addTearDown(wifi.dispose);
    addTearDown(bt.dispose);

    await tester.pumpWidget(_wrap(wifi: wifi, bluetooth: bt));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-status-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-wifi')), findsNothing);
    expect(find.byKey(const ValueKey('home-status-bt')), findsNothing);
    expect(find.byIcon(Icons.videocam), findsOneWidget);
  });

  testWidgets('wifi/bt visible when on; camera rightmost', (tester) async {
    final wifi = _FakeWifi(radioState: WifiRadioState.on);
    final bt = _FakeBt(adapter: BluetoothAdapterState.on);
    addTearDown(wifi.dispose);
    addTearDown(bt.dispose);

    await tester.pumpWidget(_wrap(wifi: wifi, bluetooth: bt));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-status-wifi')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-bt')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-camera')), findsOneWidget);

    final wifiDx =
        tester.getTopLeft(find.byKey(const ValueKey('home-status-wifi'))).dx;
    final btDx =
        tester.getTopLeft(find.byKey(const ValueKey('home-status-bt'))).dx;
    final camDx =
        tester.getTopLeft(find.byKey(const ValueKey('home-status-camera'))).dx;
    expect(wifiDx < btDx, isTrue);
    expect(btDx < camDx, isTrue);
  });

  testWidgets('wifi connecting while associating', (tester) async {
    final wifi = _FakeWifi(
      radioState: WifiRadioState.on,
      connection: const WifiConnectionState(
        phase: WifiConnectionPhase.associating,
        ssid: 'lab',
      ),
    );
    final bt = _FakeBt();
    addTearDown(wifi.dispose);
    addTearDown(bt.dispose);

    await tester.pumpWidget(_wrap(wifi: wifi, bluetooth: bt));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-status-wifi')), findsOneWidget);
    expect(find.byType(WifiSignalBarsConnecting), findsOneWidget);
  });

  testWidgets('bt connecting while adapter starting', (tester) async {
    final wifi = _FakeWifi();
    final bt = _FakeBt(adapter: BluetoothAdapterState.starting);
    addTearDown(wifi.dispose);
    addTearDown(bt.dispose);

    await tester.pumpWidget(_wrap(wifi: wifi, bluetooth: bt));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-status-bt')), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth_searching), findsOneWidget);
  });

  testWidgets('live update when wifi turns on', (tester) async {
    final wifi = _FakeWifi();
    final bt = _FakeBt();
    addTearDown(wifi.dispose);
    addTearDown(bt.dispose);

    await tester.pumpWidget(_wrap(wifi: wifi, bluetooth: bt));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-status-wifi')), findsNothing);

    wifi.emitRadio(WifiRadioState.on);
    await tester.pump();
    expect(find.byKey(const ValueKey('home-status-wifi')), findsOneWidget);
  });
}
