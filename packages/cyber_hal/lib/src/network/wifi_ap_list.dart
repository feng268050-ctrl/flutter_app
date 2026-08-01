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

  /// Partition scan + saved into My Networks / Other Networks.
  ///
  /// My Networks: unique saved SSIDs (enriched with scan signal/flags when
  /// visible). Other Networks: scanned SSIDs not in the saved set, excluding
  /// [connectedSsid] (shown in the top connected group).
  static ({
    List<WifiAccessPoint> myNetworks,
    List<WifiAccessPoint> otherNetworks,
  }) partitionMyAndOther({
    required Iterable<WifiSavedNetwork> saved,
    required Iterable<WifiAccessPoint> scanned,
    String? connectedSsid,
  }) {
    final connected = connectedSsid?.trim();
    final scanBySsid = <String, WifiAccessPoint>{};
    for (final ap in strongestBySsid(scanned)) {
      scanBySsid[ap.ssid] = ap;
    }

    final savedSsids = <String>{};
    final my = <WifiAccessPoint>[];
    for (final n in saved) {
      final ssid = n.ssid.trim();
      if (ssid.isEmpty || savedSsids.contains(ssid)) {
        continue;
      }
      savedSsids.add(ssid);
      final scannedAp = scanBySsid[ssid];
      my.add(
        scannedAp ??
            WifiAccessPoint(
              ssid: ssid,
              flags: '[WPA2-PSK]',
            ),
      );
    }

    final other = <WifiAccessPoint>[];
    for (final ap in strongestBySsid(scanned)) {
      if (savedSsids.contains(ap.ssid)) {
        continue;
      }
      if (connected != null &&
          connected.isNotEmpty &&
          ap.ssid == connected) {
        continue;
      }
      other.add(ap);
    }

    return (myNetworks: my, otherNetworks: other);
  }
}
