import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Reusable Wi-Fi client API (Linux wpa now; Android later).
abstract class WifiController {
  Stream<WifiRadioState> get radio;

  Stream<WifiConnectionState> get connection;

  /// Last known radio/connection (streams are broadcast and do not replay).
  WifiRadioState get currentRadio;

  WifiConnectionState get currentConnection;

  Future<void> setRadioEnabled(bool enabled);

  Future<List<WifiAccessPoint>> scan({Duration timeout = const Duration(seconds: 8)});

  /// [hidden] sets wpa `scan_ssid=1` for non-broadcast SSIDs.
  Future<void> connect({
    required String ssid,
    String? psk,
    bool hidden = false,
    bool save = true,
  });

  Future<void> disconnect();

  Future<void> forget(String ssid);

  Future<List<WifiSavedNetwork>> savedNetworks();

  Future<WlanIpv4Config> getIpv4Config();

  Future<void> setIpv4Config(WlanIpv4Config config);

  /// Snapshot of association + IPv4 details (for Settings / status UI).
  Future<WifiConnectionState> linkDetails();

  Future<void> dispose();
}
