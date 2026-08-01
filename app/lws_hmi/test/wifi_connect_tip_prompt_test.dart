import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/global_prompt/wifi_connect_tip_prompt.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

void main() {
  late GlobalKey<NavigatorState> navKey;
  late _FakeWifi wifi;

  setUp(() {
    navKey = GlobalKey<NavigatorState>();
    wifi = _FakeWifi(radioState: WifiRadioState.on);
    WifiConnectTipPrompt.resetForTest();
  });

  tearDown(() async {
    await wifi.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    await tester.pump();
  }

  group('suppressesTip', () {
    test('matches status-bar connecting and connected', () {
      expect(
        WifiConnectTipPrompt.suppressesTip(
          radio: WifiRadioState.starting,
          phase: WifiConnectionPhase.disconnected,
        ),
        isTrue,
      );
      expect(
        WifiConnectTipPrompt.suppressesTip(
          radio: WifiRadioState.on,
          phase: WifiConnectionPhase.associating,
        ),
        isTrue,
      );
      expect(
        WifiConnectTipPrompt.suppressesTip(
          radio: WifiRadioState.on,
          phase: WifiConnectionPhase.obtainingIp,
        ),
        isTrue,
      );
      expect(
        WifiConnectTipPrompt.suppressesTip(
          radio: WifiRadioState.on,
          phase: WifiConnectionPhase.connected,
        ),
        isTrue,
      );
      expect(
        WifiConnectTipPrompt.suppressesTip(
          radio: WifiRadioState.on,
          phase: WifiConnectionPhase.disconnected,
        ),
        isFalse,
      );
      expect(
        WifiConnectTipPrompt.suppressesTip(
          radio: WifiRadioState.on,
          phase: WifiConnectionPhase.failed,
        ),
        isFalse,
      );
    });
  });

  testWidgets('does not enqueue while associating', (tester) async {
    wifi.connectionState = const WifiConnectionState(
      phase: WifiConnectionPhase.associating,
      ssid: 'home',
    );
    final queue = GlobalPromptQueue(navigatorKey: navKey);
    await pumpApp(tester);

    await WifiConnectTipPrompt.enqueueForWifi(
      queue: queue,
      wifi: wifi,
      present: (_) async {},
    );
    await tester.pump();

    expect(queue.isIdle, isTrue);
    expect(queue.showingId, isNull);
  });

  testWidgets('dismisses pending tip when associating starts', (tester) async {
    var suppressed = true;
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester);

    unawaited(
      WifiConnectTipPrompt.enqueueForWifi(
        queue: queue,
        wifi: wifi,
        present: (_) async {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(queue.isIdle, isFalse);

    wifi.emitConnection(
      const WifiConnectionState(
        phase: WifiConnectionPhase.associating,
        ssid: 'home',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(queue.isIdle, isTrue);
    expect(queue.showingId, isNull);

    suppressed = false;
    queue.notifyGateChanged();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(queue.isIdle, isTrue);
  });

  testWidgets('dismisses pending tip when obtainingIp starts', (tester) async {
    var suppressed = true;
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester);

    unawaited(
      WifiConnectTipPrompt.enqueueForWifi(
        queue: queue,
        wifi: wifi,
        present: (_) async {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(queue.isIdle, isFalse);

    wifi.emitConnection(
      const WifiConnectionState(
        phase: WifiConnectionPhase.obtainingIp,
        ssid: 'home',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(queue.isIdle, isTrue);
    expect(queue.showingId, isNull);
  });
}

final class _FakeWifi implements WifiController {
  _FakeWifi({
    this.radioState = WifiRadioState.off,
    WifiConnectionState? connection,
  }) : connectionState = connection ?? WifiConnectionState.disconnected;

  WifiRadioState radioState;
  WifiConnectionState connectionState;

  final _radioCtrl = StreamController<WifiRadioState>.broadcast(sync: true);
  final _connCtrl = StreamController<WifiConnectionState>.broadcast(sync: true);

  void emitConnection(WifiConnectionState s) {
    connectionState = s;
    _connCtrl.add(s);
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
  Future<void> setAutoJoin(String ssid, {required bool enabled}) async {}

  @override
  Future<bool> selectSaved(String ssid) async => false;

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
