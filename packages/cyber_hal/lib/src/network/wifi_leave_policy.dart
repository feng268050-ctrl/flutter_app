/// Pure leave-policy helpers (disconnect ≠ forget) — host-testable.
enum WifiLeaveKind { disconnect, forget }

final class WifiLeavePolicy {
  const WifiLeavePolicy._();

  /// Disconnect leaves saved networks; forget removes matching SSID entries.
  static bool removesSavedNetworks(WifiLeaveKind kind) =>
      kind == WifiLeaveKind.forget;

  /// Both keep the radio link administratively UP so scan/reconnect work.
  static bool keepsLinkUp(WifiLeaveKind kind) => true;

  /// Disconnect may disable the current network to stop auto-reassoc without
  /// RemoveAllNetworks; forget removes by SSID (+ SaveConfig).
  static bool disablesCurrentNetwork(WifiLeaveKind kind) =>
      kind == WifiLeaveKind.disconnect;

  /// Networks to remove for [forget]; empty for [disconnect].
  static List<T> networksToRemove<T>({
    required WifiLeaveKind kind,
    required Iterable<T> saved,
    required String Function(T) ssidOf,
    required String forgetSsid,
  }) {
    if (kind != WifiLeaveKind.forget) {
      return const [];
    }
    final target = forgetSsid.trim();
    if (target.isEmpty) {
      return const [];
    }
    return saved.where((n) => ssidOf(n) == target).toList();
  }
}
