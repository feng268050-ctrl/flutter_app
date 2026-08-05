import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Persisted cloud preferences (`/var/lib/hmi/cloud-settings.json`).
final class CloudSettingsStore extends ChangeNotifier {
  CloudSettingsStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/cloud-settings.json';

  static const keyEnvironmentTier = 'environmentTier';
  static const keyCloudServicesEnabled = 'cloudServicesEnabled';
  static const keyLanEnhancementEnabled = 'lanEnhancementEnabled';
  static const defaultEnvironmentTier = CloudEnvironmentTier.test;
  static const defaultCloudServicesEnabled = false;
  static const defaultLanEnhancementEnabled = false;

  final String preferencePath;

  CloudEnvironmentTier _environmentTier = defaultEnvironmentTier;
  bool _cloudServicesEnabled = defaultCloudServicesEnabled;
  bool _lanEnhancementEnabled = defaultLanEnhancementEnabled;
  bool _warmed = false;

  CloudEnvironmentTier get environmentTier => _environmentTier;
  bool get cloudServicesEnabled => _cloudServicesEnabled;
  bool get lanEnhancementEnabled => _lanEnhancementEnabled;

  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        _applyJson(f.readAsStringSync());
      }
    } catch (e) {
      debugPrint('cloud-settings: warmRead failed: $e');
      _resetToDefaults();
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
      }
    } catch (e) {
      debugPrint('cloud-settings: read failed: $e');
      _resetToDefaults();
    }
    _warmed = true;
  }

  Future<void> setEnvironmentTier(CloudEnvironmentTier tier) async {
    warmRead();
    if (_environmentTier == tier) {
      return;
    }
    _environmentTier = tier;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setCloudServicesEnabled(bool enabled) async {
    warmRead();
    if (_cloudServicesEnabled == enabled) {
      return;
    }
    _cloudServicesEnabled = enabled;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setLanEnhancementEnabled(bool enabled) async {
    warmRead();
    if (_lanEnhancementEnabled == enabled) {
      return;
    }
    _lanEnhancementEnabled = enabled;
    await _writeUnlocked();
    notifyListeners();
  }

  void _resetToDefaults() {
    _environmentTier = defaultEnvironmentTier;
    _cloudServicesEnabled = defaultCloudServicesEnabled;
    _lanEnhancementEnabled = defaultLanEnhancementEnabled;
  }

  void _applyJson(String raw) {
    _resetToDefaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map.containsKey(keyEnvironmentTier)) {
        _environmentTier = CloudEnvironmentTierCodec.parse(
          map[keyEnvironmentTier]?.toString(),
        );
      }
      if (map.containsKey(keyCloudServicesEnabled)) {
        _cloudServicesEnabled = _asBool(
          map[keyCloudServicesEnabled],
          defaultCloudServicesEnabled,
        );
      }
      if (map.containsKey(keyLanEnhancementEnabled)) {
        _lanEnhancementEnabled = _asBool(
          map[keyLanEnhancementEnabled],
          defaultLanEnhancementEnabled,
        );
      }
    } catch (e) {
      debugPrint('cloud-settings: corrupt JSON, using defaults: $e');
      _resetToDefaults();
    }
  }

  static bool _asBool(Object? raw, bool fallback) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') {
        return true;
      }
      if (s == 'false' || s == '0' || s == 'no') {
        return false;
      }
    }
    return fallback;
  }

  Map<String, dynamic> _toJson() => {
        keyEnvironmentTier: _environmentTier.wireName,
        keyCloudServicesEnabled: _cloudServicesEnabled,
        keyLanEnhancementEnabled: _lanEnhancementEnabled,
      };

  Future<void> _writeUnlocked() async {
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(_toJson())}\n',
      );
    } catch (e) {
      debugPrint('cloud-settings: write failed: $e');
    }
  }
}
