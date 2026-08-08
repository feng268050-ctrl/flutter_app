/// Result of evaluating bundled + cloud candidates for one peripheral channel.
final class PeripheralFirmwareOfferEvaluation<T> {
  const PeripheralFirmwareOfferEvaluation({
    this.offer,
    this.cloudCheckFailed = false,
  });

  /// Newest-wins selection, or null when neither leg has an upgrade candidate.
  final T? offer;

  /// True when a cloud manifest fetch was attempted and failed (network/parse).
  ///
  /// Distinguishes soft-fail from a successful “no newer cloud package” result
  /// so Settings does not claim a false up-to-date when cloud was unreachable
  /// and no bundled candidate exists.
  final bool cloudCheckFailed;
}

/// Newest-wins selection between bundled and cloud peripheral candidates.
///
/// On equal typed versions, prefer [bundled] (no download).
abstract final class PeripheralFirmwareNewestWins {
  /// Returns `bundled`, `cloud`, or null when neither is present.
  ///
  /// [compare] returns negative if a < b, zero if equal, positive if a > b.
  static T? select<T>({
    required T? bundled,
    required T? cloud,
    required int Function(T a, T b) compare,
  }) {
    if (bundled == null) {
      return cloud;
    }
    if (cloud == null) {
      return bundled;
    }
    final cmp = compare(bundled, cloud);
    if (cmp > 0) {
      return bundled;
    }
    if (cmp < 0) {
      return cloud;
    }
    return bundled;
  }

  /// Control-board: higher software version wins (HW already matched by caller).
  static int compareControlBoardSw(int bundledSw, int cloudSw) =>
      bundledSw.compareTo(cloudSw);

  /// Camera: SemVer then build — caller supplies comparable keys.
  static int compareCameraKeys(
    (int, int, int, int) bundled,
    (int, int, int, int) cloud,
  ) {
    final a = bundled;
    final b = cloud;
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    if (a.$3 != b.$3) return a.$3.compareTo(b.$3);
    return a.$4.compareTo(b.$4);
  }
}
