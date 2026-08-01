import 'dart:io';

import 'package:cyber_hal/src/core/board_info.dart';
import 'package:cyber_hal/src/core/capabilities.dart';
import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/network/primary_network.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';
import 'package:flutter_test/flutter_test.dart';

BoardProfile _profile({
  Map<NetRole, String> roles = const {
    NetRole.ethernetPrimary: 'eth0',
    NetRole.wifiStation: 'wlan0',
  },
  Map<String, int> metrics = const {
    'wlan0': 100,
    'eth0': 2000,
  },
}) {
  return BoardProfile(
    info: const BoardInfo(boardId: 'test', displayName: 'Test'),
    capabilities: Capabilities.fromIds(const ['wifi', 'ethernet']),
    netRoles: roles,
    routeMetrics: metrics,
  );
}

void main() {
  late Directory tmp;
  late String prefPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hal-primary-net-');
    prefPath = '${tmp.path}/primary.conf';
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('without product pref, board metrics rank wifi first', () {
    final r = PrimaryNetworkResolver(profile: _profile(), preferencePath: prefPath);
    expect(r.primaryRole, NetRole.wifiStation);
    expect(r.primaryIface, 'wlan0');
  });

  test('setPrimaryRole persists and overrides ranking', () async {
    final ctrl = LinuxPrimaryNetworkController(
      profile: _profile(),
      preferencePath: prefPath,
    );
    await ctrl.load();
    expect(await ctrl.getPrimaryRole(), isNull);

    await ctrl.setPrimaryRole(NetRole.ethernetPrimary);
    expect(await ctrl.getPrimaryRole(), NetRole.ethernetPrimary);
    expect(ctrl.currentPrimaryRole, NetRole.ethernetPrimary);
    expect(ctrl.currentPrimary?.iface, 'eth0');
    expect(ctrl.currentPrimary?.routeMetric, PrimaryNetworkPrefs.preferredMetric);

    final wifiPath = ctrl.rankedPaths().firstWhere(
      (p) => p.role == NetRole.wifiStation,
    );
    expect(wifiPath.routeMetric, PrimaryNetworkPrefs.secondaryMetric);

    final conf = await File(prefPath).readAsString();
    expect(conf, contains('role=ethernet.primary'));
    await ctrl.dispose();
  });

  test('PrimaryNetworkPolicy.effectiveMetric reads product pref', () async {
    await PrimaryNetworkPrefs.writeRole(NetRole.ethernetPrimary, prefPath);
    expect(
      PrimaryNetworkPolicy.effectiveMetric(
        iface: 'eth0',
        role: NetRole.ethernetPrimary,
        profile: _profile(),
        prefPath: prefPath,
      ),
      PrimaryNetworkPrefs.preferredMetric,
    );
    expect(
      PrimaryNetworkPolicy.effectiveMetric(
        iface: 'wlan0',
        role: NetRole.wifiStation,
        profile: _profile(),
        prefPath: prefPath,
      ),
      PrimaryNetworkPrefs.secondaryMetric,
    );
  });

  test('setPrimaryRole rejects unmapped role', () async {
    final ctrl = LinuxPrimaryNetworkController(
      profile: _profile(roles: {NetRole.wifiStation: 'wlan0'}),
      preferencePath: prefPath,
    );
    await expectLater(
      ctrl.setPrimaryRole(NetRole.ethernetPrimary),
      throwsStateError,
    );
    await ctrl.dispose();
  });
}
