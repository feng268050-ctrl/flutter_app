import 'package:lws_hmi/features/settings/application/region_country_catalog.dart';

/// Pure Country → timezone / NTP apply decisions (host-testable).
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
  /// Decide whether to overwrite timezone / NTP when Country changes.
  ///
  /// [previousCountry] is null on first warm-read apply (no prior key).
  static RegionClockApplyPlan planClockApply({
    required String? previousCountry,
    required String nextCountry,
    required String currentTimezone,
    required bool autoTimezone,
    required String currentNtp,
  }) {
    final next = RegionCountryCatalog.entryFor(nextCountry)!;
    final prevCode = previousCountry == null
        ? null
        : RegionCountryCatalog.normalize(previousCountry);
    final prev = prevCode == null
        ? null
        : RegionCountryCatalog.entryFor(prevCode);

    final tz = currentTimezone.trim();
    final ntp = currentNtp.trim();

    final applyTimezone = !autoTimezone &&
        _timezoneIsCountryLinked(
          current: tz,
          previousDefault: prev?.defaultTimezone,
          firstApply: previousCountry == null,
        );

    final applyNtp = _ntpIsCountryLinked(
      current: ntp,
      previousPreferred: prev?.preferredNtp,
      firstApply: previousCountry == null,
    );

    return RegionClockApplyPlan(
      applyTimezone: applyTimezone,
      timezone: next.defaultTimezone,
      applyNtp: applyNtp,
      ntpServerId: next.preferredNtp,
    );
  }

  static bool _timezoneIsCountryLinked({
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
        (current == RegionCountryCatalog.legacyAsiaTimezone ||
            current == 'UTC')) {
      return true;
    }
    return false;
  }

  static bool _ntpIsCountryLinked({
    required String current,
    required String? previousPreferred,
    required bool firstApply,
  }) {
    if (current.isEmpty) {
      return true;
    }
    if (current == RegionCountryCatalog.legacyChinaNtp) {
      return true;
    }
    if (previousPreferred != null && current == previousPreferred) {
      return true;
    }
    // First apply with only catalog default still Country-linked for seed.
    if (firstApply && current == RegionCountryCatalog.preferredNtpDefault) {
      return true;
    }
    return false;
  }
}
