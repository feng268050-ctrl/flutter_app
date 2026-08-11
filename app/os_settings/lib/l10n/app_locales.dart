import 'package:flutter/material.dart';

const List<Locale> kOsSettingsSupportedLocales = <Locale>[
  Locale('en', 'US'),
  Locale('zh', 'CN'),
  Locale('zh', 'TW'),
];

/// Map HAL BCP-47 language tags to [Locale].
Locale localeFromLanguageTag(String tag) {
  switch (tag) {
    case 'zh-CN':
      return const Locale('zh', 'CN');
    case 'zh-TW':
      return const Locale('zh', 'TW');
    case 'en-US':
    default:
      return const Locale('en', 'US');
  }
}

Locale? resolveOsSettingsLocale(
  Locale? locale,
  Iterable<Locale> supportedLocales,
) {
  if (locale == null) {
    return supportedLocales.isEmpty ? null : supportedLocales.first;
  }
  for (final supported in supportedLocales) {
    if (supported.languageCode == locale.languageCode &&
        supported.countryCode == locale.countryCode) {
      return supported;
    }
  }
  if (locale.languageCode == 'zh') {
    final script = locale.scriptCode?.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (script == 'hant' ||
        country == 'TW' ||
        country == 'HK' ||
        country == 'MO') {
      return const Locale('zh', 'TW');
    }
    return const Locale('zh', 'CN');
  }
  if (locale.languageCode == 'en') {
    return const Locale('en', 'US');
  }
  return const Locale('en', 'US');
}
