/// Pure helpers for multi-profile Wi‑Fi connect / select (host-testable).
final class WifiMultiProfilePolicy {
  const WifiMultiProfilePolicy._();

  /// Sibling network paths that should stay Auto Join after SelectNetwork.
  ///
  /// [SelectNetwork] disables other configured networks; callers snapshot
  /// [enabled] before select and re-enable these paths afterward.
  static Set<String> siblingPathsToRestore({
    required Iterable<({String path, String ssid, bool enabled})> before,
    required String connectingSsid,
  }) {
    final target = connectingSsid.trim();
    return {
      for (final n in before)
        if (n.enabled && n.ssid != target) n.path,
    };
  }
}
