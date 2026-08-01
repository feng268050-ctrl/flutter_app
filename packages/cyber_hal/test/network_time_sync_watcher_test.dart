import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/core/board_info.dart';
import 'package:cyber_hal/src/core/capabilities.dart';
import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/network/ethernet_controller.dart';
import 'package:cyber_hal/src/network/ethernet_models.dart';
import 'package:cyber_hal/src/network/primary_network.dart';
import 'package:cyber_hal/src/network/wifi_controller.dart';
import 'package:cyber_hal/src/network/wifi_models.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';
import 'package:cyber_hal/src/time/network_time_sync_watcher.dart';
import 'package:cyber_hal/src/time/time_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDateTime implements DateTimeController {
  TimeSyncMode mode = TimeSyncMode.network;
  int syncCalls = 0;
  Completer<void> syncStarted = Completer<void>();

  @override
  Future<DateTime> now() async => DateTime.utc(2026, 8, 1);

  @override
  Future<TimeSyncMode> getSyncMode() async => mode;

  @override
  Future<void> setSyncMode(TimeSyncMode m) async => mode = m;

  @override
  Future<String> getTimezone() async => 'UTC';

  @override
  Future<void> setTimezone(String id) async {}

  @override
  Future<List<TimezoneEntry>> listTimezoneEntries() async => const [];

  @override
  Future<void> setWallClock(DateTime local) async {}

  @override
  Future<TimeSyncResult> syncFromNetwork({bool onlyIfStale = false}) async {
    syncCalls++;
    if (!syncStarted.isCompleted) {
      syncStarted.complete();
    }
    return const TimeSyncResult(ok: true, message: 'ok');
  }

  @override
  Future<TimeSyncResult> ensureSaneForTls() async {
    return const TimeSyncResult(ok: true, message: 'ok');
  }

  @override
  List<NtpServerPreset> listNtpServerPresets() => NtpServerCatalog.presets;

  @override
  Future<String> getNtpServerId() async => NtpServerCatalog.defaultId;

  @override
  Future<void> setNtpServerId(String id) async {}

  @override
  Future<bool> getAutoTimezone() async => false;

  @override
  Future<TimeSyncResult> setAutoTimezone(bool enabled) async {
    return const TimeSyncResult(ok: true, message: 'off');
  }

  @override
  Future<TimeSyncResult> syncTimezoneFromNetwork() async {
    return const TimeSyncResult(ok: true, message: 'ok');
  }

  @override
  Future<bool> getUse24HourFormat() async => true;

  @override
  Future<void> setUse24HourFormat(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}

class _FakeWifi implements WifiController {
  final connCtrl = StreamController<WifiConnectionState>.broadcast();
  WifiConnectionState _conn = WifiConnectionState.disconnected;

  @override
  Stream<WifiRadioState> get radio => const Stream.empty();

  @override
  Stream<WifiConnectionState> get connection => connCtrl.stream;

  @override
  String get interfaceName => 'wlan0';

  @override
  WifiRadioState get currentRadio => WifiRadioState.on;

  @override
  WifiConnectionState get currentConnection => _conn;

  void emit(WifiConnectionState s) {
    _conn = s;
    connCtrl.add(s);
  }

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
  Future<WifiConnectionState> linkDetails() async => _conn;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() async {
    await connCtrl.close();
  }
}

class _FakeEth implements EthernetController {
  final linkCtrl = StreamController<EthLinkState>.broadcast();
  EthLinkState _link = EthLinkState.down;

  @override
  String get interfaceName => 'eth0';

  @override
  Stream<EthAdminState> get admin => const Stream.empty();

  @override
  Stream<EthLinkState> get link => linkCtrl.stream;

  @override
  EthAdminState get currentAdmin => EthAdminState.on;

  @override
  EthLinkState get currentLink => _link;

  void emit(EthLinkState s) {
    _link = s;
    linkCtrl.add(s);
  }

  @override
  Future<void> setInterfaceEnabled(bool enabled) async {}

  @override
  Future<EthIpv4Config> getIpv4Config() async => EthIpv4Config.dhcpDefault;

  @override
  Future<void> setIpv4Config(EthIpv4Config config) async {}

  @override
  Future<EthLinkState> linkDetails() async => _link;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() async {
    await linkCtrl.close();
  }
}

void main() {
  late _FakeDateTime dt;
  late _FakeWifi wifi;
  late _FakeEth eth;
  late Directory tmp;
  late LinuxPrimaryNetworkController primary;

  setUp(() async {
    dt = _FakeDateTime();
    wifi = _FakeWifi();
    eth = _FakeEth();
    tmp = await Directory.systemTemp.createTemp('hal-net-time-');
    primary = LinuxPrimaryNetworkController(
      profile: BoardProfile(
        info: const BoardInfo(boardId: 'ynh960', displayName: 'ynh960'),
        capabilities: Capabilities.fromIds(const ['wifi', 'ethernet']),
        netRoles: const {
          NetRole.ethernetPrimary: 'eth0',
          NetRole.wifiStation: 'wlan0',
        },
        routeMetrics: const {
          'wlan0': 100,
          'eth0': 2000,
        },
      ),
      preferencePath: '${tmp.path}/primary.conf',
    );
    await primary.setPrimaryRole(NetRole.wifiStation);
  });

  tearDown(() async {
    await primary.dispose();
    await wifi.dispose();
    await eth.dispose();
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  NetworkTimeSyncWatcher watcher() => NetworkTimeSyncWatcher(
        dateTime: dt,
        wifi: wifi,
        ethernet: eth,
        primaryNetwork: primary,
        debounce: Duration.zero,
      );

  test('Wi-Fi primary IPv4 rising edge triggers sync', () async {
    final w = watcher()..start();
    wifi.emit(const WifiConnectionState(
      phase: WifiConnectionPhase.connected,
      ipv4: '10.0.0.5',
    ));
    await dt.syncStarted.future.timeout(const Duration(seconds: 2));
    expect(dt.syncCalls, 1);
    w.dispose();
  });

  test('Ethernet non-primary IPv4 does not trigger sync', () async {
    final w = watcher()..start();
    eth.emit(const EthLinkState(
      phase: EthLinkPhase.up,
      ipv4: '192.168.1.20',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(dt.syncCalls, 0);
    w.dispose();
  });

  test('switching primary to ethernet then makes eth link-up sync', () async {
    final w = watcher()..start();
    await primary.setPrimaryRole(NetRole.ethernetPrimary);
    eth.emit(const EthLinkState(
      phase: EthLinkPhase.up,
      ipv4: '192.168.0.2',
    ));
    await dt.syncStarted.future.timeout(const Duration(seconds: 2));
    expect(dt.syncCalls, 1);
    w.dispose();
  });
}