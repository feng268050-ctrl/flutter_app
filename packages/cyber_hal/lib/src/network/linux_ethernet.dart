import 'package:cyber_hal/network/ethernet.dart';
import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/network/networkd_dbus.dart';
import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:cyber_hal/src/network/primary_network.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';

/// Ethernet L3 via in-package networkd apply; **status via networkd D-Bus** (D11b).
class LinuxEthernet implements Ethernet {
  LinuxEthernet({
    this.profile,
    this.apply,
    this.prefRoot = '/var/lib/network',
    Map<String, int>? routeMetrics,
  }) : _apply = apply ?? NetworkdIpv4Apply(),
       _routeMetrics = routeMetrics ?? const {};

  final BoardProfile? profile;
  final NetworkdIpv4Apply? apply;
  final NetworkdIpv4Apply _apply;
  final String prefRoot;
  final Map<String, int> _routeMetrics;

  String _ifaceFor(NetRole role) {
    final fromProfile = profile?.ifaceFor(role);
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    switch (role) {
      case NetRole.ethernetPrimary:
        return 'eth0';
      case NetRole.wifiStation:
        return 'wlan0';
    }
  }

  int _metric(String iface) => PrimaryNetworkPolicy.effectiveMetric(
        iface: iface,
        role: NetRole.ethernetPrimary,
        profile: profile,
        routeMetrics: _routeMetrics,
      );

  String _prefPath(String iface) => '$prefRoot/$iface-ipv4';

  @override
  Future<EthernetStatus> status(NetRole role) async {
    final iface = _ifaceFor(role);
    final netd = NetworkdDbus();
    try {
      final snap = await netd.readLink(iface);
      return EthernetStatus(
        role: role,
        iface: iface,
        operational: snap.operational,
        addresses: snap.addresses.map((a) => a.address).toList(),
      );
    } finally {
      await netd.close();
    }
  }

  @override
  Future<void> setDhcp(NetRole role) async {
    if (role != NetRole.ethernetPrimary) {
      throw UnsupportedError('LinuxEthernet.setDhcp: only ethernet.primary');
    }
    final iface = _ifaceFor(role);
    await _apply.setLink(iface: iface, up: true);
    await _apply.apply(
      iface: iface,
      mode: 'dhcp',
      routeMetric: _metric(iface),
      prefPath: _prefPath(iface),
    );
  }

  @override
  Future<void> setStatic(
    NetRole role, {
    required String addressCidr,
    String? gateway,
    List<String> dns = const [],
  }) async {
    if (role != NetRole.ethernetPrimary) {
      throw UnsupportedError('LinuxEthernet.setStatic: only ethernet.primary');
    }
    final iface = _ifaceFor(role);
    final parts = addressCidr.split('/');
    final addr = parts.first;
    final prefix = parts.length > 1 ? parts[1] : '24';
    await _apply.setLink(iface: iface, up: true);
    await _apply.apply(
      iface: iface,
      mode: 'static',
      routeMetric: _metric(iface),
      address: addr,
      prefix: prefix,
      gateway: gateway,
      dns: dns.isNotEmpty ? dns.first : null,
      prefPath: _prefPath(iface),
    );
  }
}
