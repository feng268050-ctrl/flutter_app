/// Locale HAL — PreferredLanguage, UnitSystem, Region (+ regulatory apply).
///
/// Linux prefs: `/var/lib/hal/locale.conf`
/// (`language`, `unit`, `region`).
library;

export 'package:cyber_hal/src/locale/locale_settings.dart';
export 'package:cyber_hal/src/locale/locale_types.dart';
export 'package:cyber_hal/src/locale/region_catalog.dart';
export 'package:cyber_hal/src/locale/region_settings_applier.dart';
export 'package:cyber_hal/src/locale/region_settings_policy.dart';
