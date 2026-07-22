/// Phone-like status-bar visibility/phase for Wi‑Fi / Bluetooth glyphs.
enum CyberConnectivityIconPhase {
  /// Radio/adapter off — do not render the glyph.
  hidden,

  /// In-progress (associating, adapter starting, pairing, …).
  connecting,

  /// Link up / at least one remote connected.
  connected,

  /// Enabled but not linked.
  onIdle,
}

/// Status-bar Wi‑Fi bar count from RSSI (dBm).
///
/// Returns **0** for “no link” callers, **1–4** when associated.
/// Unknown RSSI while connected → **4** (optimistic full bars).
int cyberWifiSignalBarsFromDbm(int? signalDbm, {required bool linked}) {
  if (!linked) {
    return 0;
  }
  if (signalDbm == null) {
    return 4;
  }
  if (signalDbm >= -55) {
    return 4;
  }
  if (signalDbm >= -65) {
    return 3;
  }
  if (signalDbm >= -75) {
    return 2;
  }
  return 1;
}
