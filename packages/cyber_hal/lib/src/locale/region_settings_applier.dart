import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/src/locale/locale_settings.dart';
import 'package:cyber_hal/src/locale/region_catalog.dart';
import 'package:cyber_hal/src/locale/region_settings_policy.dart';
import 'package:flutter/foundation.dart';

/// Applies Region preference to Wi‑Fi regulatory + linked timezone / NTP.
final class RegionSettingsApplier {
  RegionSettingsApplier({
    required this.dateTime,
    this.wifiIface,
    this.wpaConfPath = WifiCountryApply.defaultWpaConfPath,
    Future<bool> Function(String region)? applyWifiCountry,
  }) : _applyWifiCountry = applyWifiCountry;

  final DateTimeController dateTime;
  final String? wifiIface;
  final String wpaConfPath;
  final Future<bool> Function(String region)? _applyWifiCountry;

  /// Boot / warm-read: apply persisted Region.
  Future<void> applyAfterWarmRead(LocaleSettings settings) async {
    settings.warmRead();
    final previous =
        settings.hadPersistedRegion ? settings.region : null;
    await apply(
      previousRegion: previous,
      nextRegion: settings.region,
    );
    // Seed `region` key so subsequent boots treat Region as persisted.
    if (!settings.hadPersistedRegion) {
      await settings.setRegion(settings.region);
    }
  }

  /// Operator changed Region in Settings.
  Future<void> applyRegionChange({
    required String previousRegion,
    required String nextRegion,
  }) async {
    await apply(
      previousRegion: previousRegion,
      nextRegion: nextRegion,
    );
  }

  Future<void> apply({
    required String? previousRegion,
    required String nextRegion,
  }) async {
    final next = RegionCatalog.normalize(nextRegion);

    try {
      final wifiFn = _applyWifiCountry ??
          ((cc) => WifiCountryApply.apply(
                country: cc,
                wpaConfPath: wpaConfPath,
                iface: wifiIface,
              ));
      await wifiFn(next);
    } catch (e) {
      debugPrint('region-settings: wifi country apply failed: $e');
    }

    try {
      final tz = await dateTime.getTimezone();
      final ntp = await dateTime.getNtpServerId();
      final autoTz = await dateTime.getAutoTimezone();
      final plan = RegionSettingsPolicy.planClockApply(
        previousRegion: previousRegion,
        nextRegion: next,
        currentTimezone: tz,
        autoTimezone: autoTz,
        currentNtp: ntp,
      );
      if (plan.applyTimezone) {
        await dateTime.setTimezone(plan.timezone);
      }
      if (plan.applyNtp) {
        await dateTime.setNtpServerId(plan.ntpServerId);
      }
    } catch (e) {
      debugPrint('region-settings: clock apply failed: $e');
    }
  }
}
