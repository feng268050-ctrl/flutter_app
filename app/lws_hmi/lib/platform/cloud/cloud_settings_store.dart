import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/network/cloud_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

export 'package:cyber_hal/network/cloud_environment.dart'
    show
        CloudEnvironmentTier,
        CloudEnvironmentTierCodec,
        kCloudEnvironmentTiers;

/// Product cloud opt-in prefs (`/var/lib/hmi/cloud-settings.json`) plus shared
/// API env tier (`/var/lib/network/cloud.conf` via [CloudEnvironmentPrefs]).
final class CloudSettingsStore extends ChangeNotifier {
  CloudSettingsStore({
    String? preferencePath,
    String? environmentTierPath,
    String? legacyEnvironmentJsonPath,
  })  : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/cloud-settings.json',
        environmentTierPath =
            environmentTierPath ?? CloudEnvironmentPrefs.confPath,
        legacyEnvironmentJsonPath = legacyEnvironmentJsonPath ??
            preferencePath ??
            '${OsPaths.varHmi}/cloud-settings.json';

  static const keyCloudServicesEnabled = 'cloudServicesEnabled';
  static const keyLanEnhancementEnabled = 'lanEnhancementEnabled';
  static const defaultEnvironmentTier = CloudEnvironmentTier.prod;
  static const defaultCloudServicesEnabled = false;
  static const defaultLanEnhancementEnabled = false;

  /// HMI-only product toggles (not the shared API tier).
  final String preferencePath;

  /// Shared platform tier (`cloud.conf`).
  final String environmentTierPath;

  /// Legacy JSON used only to migrate [environmentTier] into [environmentTierPath].
  final String legacyEnvironmentJsonPath;

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
      _environmentTier = CloudEnvironmentPrefs.readOrMigrateSync(
        conf: environmentTierPath,
        legacyJson: legacyEnvironmentJsonPath,
      );
      final f = File(preferencePath);
      if (f.existsSync()) {
        _applyProductJson(f.readAsStringSync());
      }
    } catch (e) {
      debugPrint('cloud-settings: warmRead failed: $e');
      _resetProductDefaults();
      _environmentTier = defaultEnvironmentTier;
    }
    _warmed = true;
  }

  Future<void> read() async {
    if (_warmed) {
      return;
    }
    try {
      _environmentTier = await CloudEnvironmentPrefs.readOrMigrate(
        conf: environmentTierPath,
        legacyJson: legacyEnvironmentJsonPath,
      );
      final f = File(preferencePath);
      if (await f.exists()) {
        _applyProductJson(await f.readAsString());
      }
    } catch (e) {
      debugPrint('cloud-settings: read failed: $e');
      _resetProductDefaults();
      _environmentTier = defaultEnvironmentTier;
    }
    _warmed = true;
  }

  Future<void> setEnvironmentTier(CloudEnvironmentTier tier) async {
    warmRead();
    if (_environmentTier == tier) {
      return;
    }
    _environmentTier = tier;
    await CloudEnvironmentPrefs.write(tier, environmentTierPath);
    notifyListeners();
  }

  Future<void> setCloudServicesEnabled(bool enabled) async {
    warmRead();
    if (_cloudServicesEnabled == enabled) {
      return;
    }
    _cloudServicesEnabled = enabled;
    await _writeProductUnlocked();
    notifyListeners();
  }

  Future<void> setLanEnhancementEnabled(bool enabled) async {
    warmRead();
    if (_lanEnhancementEnabled == enabled) {
      return;
    }
    _lanEnhancementEnabled = enabled;
    await _writeProductUnlocked();
    notifyListeners();
  }

  void _resetProductDefaults() {
    _cloudServicesEnabled = defaultCloudServicesEnabled;
    _lanEnhancementEnabled = defaultLanEnhancementEnabled;
  }

  void _applyProductJson(String raw) {
    _resetProductDefaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
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
      _resetProductDefaults();
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

  Map<String, dynamic> _toProductJson() => {
        keyCloudServicesEnabled: _cloudServicesEnabled,
        keyLanEnhancementEnabled: _lanEnhancementEnabled,
      };

  Future<void> _writeProductUnlocked() async {
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(_toProductJson())}\n',
      );
    } catch (e) {
      debugPrint('cloud-settings: write failed: $e');
    }
  }
}
