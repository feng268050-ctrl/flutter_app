import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Pure parsers for `wpa_cli` text (host-testable).
class WpaCliParse {
  /// Whether connect should set `scan_ssid=1`.
  static bool needsScanSsid({required bool hidden}) => hidden;

  static Map<String, String> status(String text) {
    final out = <String, String>{};
    for (final line in text.split('\n')) {
      final t = line.trim();
      final i = t.indexOf('=');
      if (i <= 0) {
        continue;
      }
      out[t.substring(0, i)] = t.substring(i + 1);
    }
    return out;
  }

  static WifiConnectionPhase phaseFromStatus(Map<String, String> st) {
    final wpa = (st['wpa_state'] ?? '').toUpperCase();
    switch (wpa) {
      case 'COMPLETED':
        return WifiConnectionPhase.connected;
      case 'ASSOCIATING':
      case 'ASSOCIATED':
      case 'AUTHENTICATING':
      case '4WAY_HANDSHAKE':
      case 'GROUP_HANDSHAKE':
        return WifiConnectionPhase.associating;
      case 'DISCONNECTED':
      case 'INACTIVE':
      case 'INTERFACE_DISABLED':
        return WifiConnectionPhase.disconnected;
      default:
        if (wpa.isEmpty) {
          return WifiConnectionPhase.disconnected;
        }
        return WifiConnectionPhase.associating;
    }
  }

  /// `bssid / frequency / signal / flags / ssid` tab-separated (scan_results).
  /// Duplicate SSIDs keep the strongest RSSI (roaming-friendly).
  static List<WifiAccessPoint> scanResults(String text) {
    final best = <String, WifiAccessPoint>{};
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('bssid')) {
        continue;
      }
      final parts = t.split('\t');
      if (parts.length < 5) {
        continue;
      }
      final ssid = parts.sublist(4).join('\t').trim();
      if (ssid.isEmpty) {
        continue;
      }
      final signal = int.tryParse(parts[2]);
      final ap = WifiAccessPoint(
        ssid: ssid,
        signalDbm: signal,
        flags: parts[3],
      );
      final prev = best[ssid];
      if (prev == null ||
          (ap.signalDbm ?? -999) > (prev.signalDbm ?? -999)) {
        best[ssid] = ap;
      }
    }
    final aps = best.values.toList()
      ..sort(
        (a, b) => (b.signalDbm ?? -999).compareTo(a.signalDbm ?? -999),
      );
    return aps;
  }

  static List<WifiSavedNetwork> listNetworks(String text) {
    final out = <WifiSavedNetwork>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('network id')) {
        continue;
      }
      final parts = t.split('\t');
      if (parts.length < 2) {
        continue;
      }
      final id = int.tryParse(parts[0]);
      if (id == null) {
        continue;
      }
      var ssid = parts[1].trim();
      if (ssid.startsWith('"') && ssid.endsWith('"') && ssid.length >= 2) {
        ssid = ssid.substring(1, ssid.length - 1);
      }
      if (ssid == 'any' || ssid.isEmpty) {
        continue;
      }
      out.add(WifiSavedNetwork(networkId: id, ssid: ssid));
    }
    return out;
  }

  /// Escape for `set_network ssid` / quoted wpa values — never log the result with PSK.
  static String quoteWpaString(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
