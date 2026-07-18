import 'dart:io';

import 'package:cyber_hal/network/wifi.dart';
import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/network/networkd_dbus.dart';
import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:cyber_hal/src/network/wifi_radio.dart';
import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';

/// Wi‑Fi: injected [WifiRadio] + wpa D-Bus L2 + in-package L3 apply (D11b).
class LinuxWifi implements Wifi {
  LinuxWifi({
    this.profile,
    WifiRadio? radio,
    NetworkdIpv4Apply? apply,
    WpaSupplicantDbus? wpa,
    this.prefRoot = '/var/lib/wpa_supplicant',
    Map<String, int>? routeMetrics,
    this.scanSettle = const Duration(seconds: 2),
  }) : _radio = radio ?? SystemdWifiRadio(),
       _apply = apply ?? NetworkdIpv4Apply(),
       _wpa = wpa,
       _routeMetrics = routeMetrics ?? const {};

  final BoardProfile? profile;
  final WifiRadio _radio;
  final NetworkdIpv4Apply _apply;
  final WpaSupplicantDbus? _wpa;
  final String prefRoot;
  final Map<String, int> _routeMetrics;
  final Duration scanSettle;

  String get iface {
    final fromProfile = profile?.ifaceFor(NetRole.wifiStation);
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    return 'wlan0';
  }

  int get _metric =>
      _routeMetrics[iface] ??
      profile?.routeMetricFor(iface) ??
      NetworkdIpv4Apply.defaultRouteMetric(iface);

  String get _prefPath => '$prefRoot/$iface-ipv4';

  Future<WpaSupplicantDbus> _openWpa() async {
    return _wpa ?? WpaSupplicantDbus();
  }

  Future<void> _closeIfOwned(WpaSupplicantDbus wpa) async {
    if (!identical(wpa, _wpa)) {
      await wpa.close();
    }
  }

  @override
  Future<bool> isEnabled() => _radio.isEnabled();

  @override
  Future<void> setEnabled(bool enabled) => _radio.setEnabled(enabled);

  @override
  Future<List<WifiAccessPoint>> scan() async {
    await setEnabled(true);
    final wpa = await _openWpa();
    try {
      await wpa.scan(iface);
      await Future<void>.delayed(scanSettle);
      final rows = await wpa.listScanResults(iface);
      return rows
          .map(
            (r) => WifiAccessPoint(
              ssid: r.ssid,
              signalDbm: r.signalDbm,
              flags: r.secured ? '[WPA2-PSK-CCMP]' : '[ESS]',
              bssid: r.bssid,
            ),
          )
          .toList();
    } finally {
      await _closeIfOwned(wpa);
    }
  }

  @override
  Future<void> connect({required String ssid, String? psk}) async {
    await setEnabled(true);
    final wpa = await _openWpa();
    try {
      await wpa.connectNetwork(iface, ssid: ssid, psk: psk);
    } finally {
      await _closeIfOwned(wpa);
    }
    await _apply.apply(
      iface: iface,
      mode: 'dhcp',
      routeMetric: _metric,
      prefPath: _prefPath,
    );
  }

  @override
  Future<void> disconnect() async {
    final wpa = await _openWpa();
    try {
      await wpa.disconnect(iface);
      await wpa.disableCurrentNetwork(iface);
    } finally {
      await _closeIfOwned(wpa);
    }
    // Keep link up for rescan / reconnect (D11b Demo parity). Do not
    // RemoveAllNetworks — that is forget/connect appliance replacement only.
    try {
      await _apply.setLink(iface: iface, up: true);
      await Process.run('networkctl', ['reconfigure', iface]);
    } catch (_) {}
  }

  @override
  Future<WifiConnectionStatus> status() async {
    final wpa = await _openWpa();
    final netd = NetworkdDbus();
    try {
      final snap = await wpa.readIface(iface);
      final link = await netd.readLink(iface);
      return WifiConnectionStatus(
        ssid: snap.ssid,
        iface: iface,
        addresses: link.addresses.map((a) => a.address).toList(),
      );
    } finally {
      await _closeIfOwned(wpa);
      await netd.close();
    }
  }
}
