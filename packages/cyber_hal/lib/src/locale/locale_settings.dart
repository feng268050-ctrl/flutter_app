import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/locale/locale_types.dart';
import 'package:cyber_hal/src/locale/region_catalog.dart';
import 'package:flutter/foundation.dart';

/// HAL locale prefs: PreferredLanguage / UnitSystem / Region.
///
/// Persist path: `/var/lib/hal/locale.conf` (`language`, `unit`, `region`).
/// Does **not** read `/var/lib/hmi/common-settings.json`.
final class LocaleSettings extends ChangeNotifier {
  LocaleSettings({String? preferencePath})
      : preferencePath = preferencePath ?? LocalePrefs.localeConf;

  final String preferencePath;

  PreferredLanguage _language = PreferredLanguage.defaultValue;
  UnitSystem _unit = UnitSystem.defaultValue;
  String _region = RegionCatalog.defaultRegion;
  bool _warmed = false;
  bool _regionKeyPresent = false;

  PreferredLanguage get language => _language;
  UnitSystem get unit => _unit;

  /// ISO alpha-2 Region (normalized).
  String get region => _region;

  /// Wire helpers for App / cloud snapshot.
  String get languageWire => _language.wire;
  String get unitWire => _unit.wire;

  /// True when last read found a `region` key.
  bool get hadPersistedRegion => _regionKeyPresent;

  /// Synchronous warm-read for bootstrap.
  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      final map = readKeyValueConfFileSync(preferencePath);
      _applyMap(map);
    } catch (e) {
      debugPrint('locale: warmRead failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> read() async {
    if (_warmed) {
      return;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      _applyMap(map);
    } catch (e) {
      debugPrint('locale: read failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> setLanguage(PreferredLanguage value) async {
    warmRead();
    if (_language == value) {
      return;
    }
    _language = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setLanguageWire(String value) =>
      setLanguage(PreferredLanguage.parse(value));

  Future<void> setUnit(UnitSystem value) async {
    warmRead();
    if (_unit == value) {
      return;
    }
    _unit = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setUnitWire(String value) => setUnit(UnitSystem.parse(value));

  /// Persist Region. Does not apply Wi‑Fi / clock side effects —
  /// callers use [RegionSettingsApplier].
  Future<void> setRegion(String value) async {
    warmRead();
    final next = RegionCatalog.normalize(value);
    if (_region == next && _regionKeyPresent) {
      return;
    }
    _region = next;
    _regionKeyPresent = true;
    await _writeUnlocked();
    notifyListeners();
  }

  void _applyDefaults() {
    _language = PreferredLanguage.defaultValue;
    _unit = UnitSystem.defaultValue;
    _region = RegionCatalog.defaultRegion;
    _regionKeyPresent = false;
  }

  void _applyMap(Map<String, String> map) {
    _applyDefaults();
    if (map.containsKey(LocalePrefs.keyLanguage)) {
      _language = PreferredLanguage.parse(map[LocalePrefs.keyLanguage]);
    }
    if (map.containsKey(LocalePrefs.keyUnit)) {
      _unit = UnitSystem.parse(map[LocalePrefs.keyUnit]);
    }
    if (map.containsKey(LocalePrefs.keyRegion)) {
      _region = RegionCatalog.normalize(map[LocalePrefs.keyRegion]);
      _regionKeyPresent = true;
    }
  }

  Future<void> _writeUnlocked() async {
    await upsertKeyValueConfFile(preferencePath, {
      LocalePrefs.keyLanguage: _language.wire,
      LocalePrefs.keyUnit: _unit.wire,
      LocalePrefs.keyRegion: _region,
    });
  }
}

/// Paths and keys for [LocaleSettings].
abstract final class LocalePrefs {
  static const localeConf = '/var/lib/hal/locale.conf';
  static const keyLanguage = 'language';
  static const keyUnit = 'unit';
  static const keyRegion = 'region';
}
