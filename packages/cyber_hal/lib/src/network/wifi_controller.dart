import 'package:cyber_hal/src/network/wifi_models.dart';

/// Reusable Wi-Fi client API (Linux wpa now; Android later).
abstract class WifiController {
  Stream<WifiRadioState> get radio;

  Stream<WifiConnectionState> get connection;

  /// Station iface from board profile (e.g. `wlan0`).
  String get interfaceName;

  /// Last known radio/connection (streams are broadcast and do not replay).
  WifiRadioState get currentRadio;

  WifiConnectionState get currentConnection;

  Future<void> setRadioEnabled(bool enabled);

  Future<List<WifiAccessPoint>> scan({Duration timeout = const Duration(seconds: 8)});

  /// [hidden] sets wpa `scan_ssid=1` for non-broadcast SSIDs.
  /// [bssid] optionally pins a BSS (Demo leaves null so same-SSID can roam).
  /// [requiresPsk] when true, empty PSK fails instead of treating the AP as open.
  ///
  /// Appliance policy: [connect] may replace the wpa network selection (single
  /// active network) via [WpaSupplicantDbus.connectNetwork] — that is intentional
  /// for this product line, not a general multi-profile manager. Config is always
  /// SaveConfig'd after select.
  Future<void> connect({
    required String ssid,
    String? psk,
    String? bssid,
    bool hidden = false,
    bool requiresPsk = false,
  });

  /// Leave the current BSS without forgetting saved networks.
  Future<void> disconnect();

  /// Remove saved networks for [ssid] (+ SaveConfig); disconnect if current.
  Future<void> forget(String ssid);

  Future<List<WifiSavedNetwork>> savedNetworks();

  Future<WlanIpv4Config> getIpv4Config();

  Future<void> setIpv4Config(WlanIpv4Config config);

  /// Snapshot of association + IPv4 details (for Settings / status UI).
  Future<WifiConnectionState> linkDetails();

  /// Align radio/connection with the live system (after boot restore).
  Future<void> syncFromSystem();

  Future<void> dispose();
}
