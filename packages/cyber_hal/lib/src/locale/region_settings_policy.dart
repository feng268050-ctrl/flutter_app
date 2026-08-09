import 'package:cyber_hal/src/locale/region_catalog.dart';

/// Pure Region → timezone / NTP apply decisions (host-testable).
final class RegionClockApplyPlan {
  const RegionClockApplyPlan({
    required this.applyTimezone,
    required this.timezone,
    required this.applyNtp,
    required this.ntpServerId,
  });

  final bool applyTimezone;
  final String timezone;
  final bool applyNtp;
  final String ntpServerId;
}

abstract final class RegionSettingsPolicy {
  /// Decide whether to overwrite timezone / NTP when Region changes.
  ///
  /// [previousRegion] is null on first warm-read apply (no prior key).
  static RegionClockApplyPlan planClockApply({
    required String? previousRegion,
    required String nextRegion,
    required String currentTimezone,
    required bool autoTimezone,
    required String currentNtp,
  }) {
    final next = RegionCatalog.entryFor(nextRegion)!;
    final prevCode = previousRegion == null
        ? null
        : RegionCatalog.normalize(previousRegion);
    final prev =
        prevCode == null ? null : RegionCatalog.entryFor(prevCode);

    final tz = currentTimezone.trim();
    final ntp = currentNtp.trim();

    final applyTimezone = !autoTimezone &&
        _timezoneIsRegionLinked(
          current: tz,
          previousDefault: prev?.defaultTimezone,
          firstApply: previousRegion == null,
        );

    final applyNtp = _ntpIsRegionLinked(
      current: ntp,
      previousPreferred: prev?.preferredNtp,
      firstApply: previousRegion == null,
    );

    return RegionClockApplyPlan(
      applyTimezone: applyTimezone,
      timezone: next.defaultTimezone,
      applyNtp: applyNtp,
      ntpServerId: next.preferredNtp,
    );
  }

  static bool _timezoneIsRegionLinked({
    required String current,
    required String? previousDefault,
    required bool firstApply,
  }) {
    if (current.isEmpty) {
      return true;
    }
    if (previousDefault != null && current == previousDefault) {
      return true;
    }
    if (firstApply &&
        (current == RegionCatalog.legacyAsiaTimezone || current == 'UTC')) {
      return true;
    }
    return false;
  }

  static bool _ntpIsRegionLinked({
    required String current,
    required String? previousPreferred,
    required bool firstApply,
  }) {
    if (current.isEmpty) {
      return true;
    }
    if (current == RegionCatalog.legacyChinaNtp) {
      return true;
    }
    if (previousPreferred != null && current == previousPreferred) {
      return true;
    }
    if (firstApply && current == RegionCatalog.preferredNtpDefault) {
      return true;
    }
    return false;
  }
}
