import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/region_country_catalog.dart';
import 'package:lws_hmi/l10n/app_locales.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// App-owned Common Settings product prefs (`/var/lib/hmi/common-settings.json`).
///
/// Language / Unit / Country (and future non-HAL, non-Misc peers). Not Misc JSON; not HAL.
final class CommonSettingsStore extends ChangeNotifier {
  CommonSettingsStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/common-settings.json';

  static const keyLanguage = 'language';
  static const keyUnit = 'unit';
  static const keyCountry = 'country';

  /// BCP-47 wire values (persisted).
  static const languageEnUs = 'en-US';
  static const languageZhCn = 'zh-CN';
  static const languageZhTw = 'zh-TW';

  /// Legacy wire values accepted on read only.
  static const languageLegacyEn = 'EN';
  static const languageLegacyZh = 'ZH';

  static const unitMetric = 'Metric';
  static const unitImperial = 'Imperial';

  static const defaultLanguage = languageEnUs;
  static const defaultUnit = unitMetric;
  static const defaultCountry = RegionCountryCatalog.defaultCountry;

  static const supportedLanguages = <String>[
    languageEnUs,
    languageZhCn,
    languageZhTw,
  ];
  static const supportedUnits = <String>[unitMetric, unitImperial];
  static const supportedCountries = RegionCountryCatalog.supportedCodes;

  final String preferencePath;

  String _language = defaultLanguage;
  String _unit = defaultUnit;
  String _country = defaultCountry;
  bool _warmed = false;
  bool _countryKeyPresent = false;

  String get language => _language;
  String get unit => _unit;
  String get country => _country;

  /// True when last read found a `country` key (false → default US, first migrate).
  bool get hadPersistedCountry => _countryKeyPresent;

  /// Flutter [Locale] for [MaterialApp.locale].
  Locale get locale => localeFromLanguageTag(_language);

  /// Endonym for [code] — always the language’s own script/name, never
  /// translated to the current UI locale (English / 简体中文 / 繁體中文).
  static String languageEndonym(String code) {
    switch (normalizeLanguage(code)) {
      case languageZhCn:
        return '简体中文';
      case languageZhTw:
        return '繁體中文';
      case languageEnUs:
      default:
        return 'English';
    }
  }

  /// Endonym for the active Language preference.
  String get languageLabel => languageEndonym(_language);

  /// Whether the language prefers Chinese IME (Simplified or Traditional).
  bool get isChineseLanguage =>
      _language == languageZhCn || _language == languageZhTw;

  /// Synchronous warm-read for bootstrap.
  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        _applyJson(f.readAsStringSync());
      } else {
        _applyDefaults();
      }
    } catch (e) {
      debugPrint('common-settings: warmRead failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> read() async {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (await f.exists()) {
        _applyJson(await f.readAsString());
      } else {
        _applyDefaults();
      }
    } catch (e) {
      debugPrint('common-settings: read failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> setLanguage(String value) async {
    warmRead();
    final next = normalizeLanguage(value);
    if (_language == next) {
      return;
    }
    _language = next;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setUnit(String value) async {
    warmRead();
    final next = normalizeUnit(value);
    if (_unit == next) {
      return;
    }
    _unit = next;
    await _writeUnlocked();
    notifyListeners();
  }

  /// Persist Country (ISO alpha-2). Does not apply Wi‑Fi / clock side effects —
  /// callers use [RegionSettingsApplier].
  Future<void> setCountry(String value) async {
    warmRead();
    final next = normalizeCountry(value);
    if (_country == next && _countryKeyPresent) {
      return;
    }
    _country = next;
    _countryKeyPresent = true;
    await _writeUnlocked();
    notifyListeners();
  }

  static String normalizeLanguage(String? value) {
    switch (value) {
      case languageZhCn:
      case languageLegacyZh:
        return languageZhCn;
      case languageZhTw:
        return languageZhTw;
      case languageEnUs:
      case languageLegacyEn:
        return languageEnUs;
      default:
        return defaultLanguage;
    }
  }

  static String normalizeUnit(String? value) {
    if (value == unitImperial) {
      return unitImperial;
    }
    if (value == unitMetric) {
      return unitMetric;
    }
    return defaultUnit;
  }

  static String normalizeCountry(String? value) =>
      RegionCountryCatalog.normalize(value);

  void _applyDefaults() {
    _language = defaultLanguage;
    _unit = defaultUnit;
    _country = defaultCountry;
    _countryKeyPresent = false;
  }

  void _applyJson(String raw) {
    _applyDefaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map.containsKey(keyLanguage)) {
        _language = normalizeLanguage('${map[keyLanguage]}');
      }
      if (map.containsKey(keyUnit)) {
        _unit = normalizeUnit('${map[keyUnit]}');
      }
      if (map.containsKey(keyCountry)) {
        _country = normalizeCountry('${map[keyCountry]}');
        _countryKeyPresent = true;
      }
    } catch (e) {
      debugPrint('common-settings: corrupt JSON, using defaults: $e');
      _applyDefaults();
    }
  }

  Map<String, dynamic> _toJson() => {
        keyLanguage: _language,
        keyUnit: _unit,
        keyCountry: _country,
      };

  Future<void> _writeUnlocked() async {
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(_toJson())}\n',
      );
    } catch (e) {
      debugPrint('common-settings: write failed: $e');
    }
  }
}
