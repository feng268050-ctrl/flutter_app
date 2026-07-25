import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_locales.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// App-owned Common Settings product prefs (`/var/lib/hmi/common-settings.json`).
///
/// Language / Unit (and future non-HAL, non-Misc peers). Not Misc JSON; not HAL.
final class CommonSettingsStore extends ChangeNotifier {
  CommonSettingsStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/common-settings.json';

  static const keyLanguage = 'language';
  static const keyUnit = 'unit';

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

  static const supportedLanguages = <String>[
    languageEnUs,
    languageZhCn,
    languageZhTw,
  ];
  static const supportedUnits = <String>[unitMetric, unitImperial];

  final String preferencePath;

  String _language = defaultLanguage;
  String _unit = defaultUnit;
  bool _warmed = false;

  String get language => _language;
  String get unit => _unit;

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

  void _applyDefaults() {
    _language = defaultLanguage;
    _unit = defaultUnit;
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
    } catch (e) {
      debugPrint('common-settings: corrupt JSON, using defaults: $e');
      _applyDefaults();
    }
  }

  Map<String, dynamic> _toJson() => {
        keyLanguage: _language,
        keyUnit: _unit,
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
