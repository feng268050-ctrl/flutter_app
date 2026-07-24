import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  static const languageEn = 'EN';
  static const languageZh = 'ZH';
  static const unitMetric = 'Metric';
  static const unitImperial = 'Imperial';

  static const defaultLanguage = languageEn;
  static const defaultUnit = unitMetric;

  static const supportedLanguages = <String>[languageEn, languageZh];
  static const supportedUnits = <String>[unitMetric, unitImperial];

  final String preferencePath;

  String _language = defaultLanguage;
  String _unit = defaultUnit;
  bool _warmed = false;

  String get language => _language;
  String get unit => _unit;

  /// Display label for Common Settings Language row.
  String get languageLabel =>
      _language == languageZh ? '中文' : 'English';

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
    if (value == languageZh) {
      return languageZh;
    }
    if (value == languageEn) {
      return languageEn;
    }
    return defaultLanguage;
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
