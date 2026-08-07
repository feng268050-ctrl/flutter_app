import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/network.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/region_country_catalog.dart';
import 'package:lws_hmi/features/settings/application/region_settings_policy.dart';

/// Applies Country preference to Wi‑Fi regulatory + linked timezone / NTP.
final class RegionSettingsApplier {
  RegionSettingsApplier({
    required this.dateTime,
    this.wifiIface,
    this.wpaConfPath = WifiCountryApply.defaultWpaConfPath,
    Future<bool> Function(String country)? applyWifiCountry,
  }) : _applyWifiCountry = applyWifiCountry;

  final DateTimeController dateTime;
  final String? wifiIface;
  final String wpaConfPath;
  final Future<bool> Function(String country)? _applyWifiCountry;

  /// Boot / warm-read: apply persisted Country.
  Future<void> applyAfterWarmRead(CommonSettingsStore store) async {
    store.warmRead();
    final previous =
        store.hadPersistedCountry ? store.country : null;
    await apply(
      previousCountry: previous,
      nextCountry: store.country,
    );
    // Seed `country` key so subsequent boots treat Country as persisted.
    if (!store.hadPersistedCountry) {
      await store.setCountry(store.country);
    }
  }

  /// Operator changed Country in Settings.
  Future<void> applyCountryChange({
    required String previousCountry,
    required String nextCountry,
  }) async {
    await apply(
      previousCountry: previousCountry,
      nextCountry: nextCountry,
    );
  }

  Future<void> apply({
    required String? previousCountry,
    required String nextCountry,
  }) async {
    final next = RegionCountryCatalog.normalize(nextCountry);

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
        previousCountry: previousCountry,
        nextCountry: next,
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
