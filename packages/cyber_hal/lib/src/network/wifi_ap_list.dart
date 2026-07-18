import 'package:cyber_hal/src/network/wifi_models.dart';

/// Pure list helpers for Demo / Settings — host-testable, no I/O.
class WifiApList {
  /// One row per SSID, strongest RSSI wins (Wi‑Fi roaming style).
  static List<WifiAccessPoint> strongestBySsid(Iterable<WifiAccessPoint> aps) {
    final best = <String, WifiAccessPoint>{};
    for (final ap in aps) {
      final ssid = ap.ssid.trim();
      if (ssid.isEmpty) {
        continue;
      }
      final prev = best[ssid];
      if (prev == null ||
          (ap.signalDbm ?? -999) > (prev.signalDbm ?? -999)) {
        best[ssid] = ap;
      }
    }
    final out = best.values.toList()
      ..sort(
        (a, b) => (b.signalDbm ?? -999).compareTo(a.signalDbm ?? -999),
      );
    return out;
  }

  /// Networks shown in the “available” list — excludes the active SSID.
  static List<WifiAccessPoint> available({
    required Iterable<WifiAccessPoint> scanned,
    String? connectedSsid,
  }) {
    final connected = connectedSsid?.trim();
    final deduped = strongestBySsid(scanned);
    if (connected == null || connected.isEmpty) {
      return deduped;
    }
    return deduped.where((ap) => ap.ssid != connected).toList();
  }
}
