import 'package:cyber_hal/src/network/wifi_models.dart';

export 'package:cyber_hal/src/network/wifi_models.dart'
    show WifiAccessPoint;

/// Wi‑Fi L2 (wpa D-Bus) + L3 (networkd). Compact HAL surface (non-Stream).
///
/// Demo / Settings prefer [WifiController] / [LinuxWifiSession].
abstract class Wifi {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);

  Future<List<WifiAccessPoint>> scan();

  Future<void> connect({
    required String ssid,
    String? psk,
  });

  Future<void> disconnect();

  Future<WifiConnectionStatus> status();
}

final class WifiConnectionStatus {
  const WifiConnectionStatus({
    this.ssid,
    this.iface,
    this.addresses = const [],
  });

  final String? ssid;
  final String? iface;
  final List<String> addresses;
}
