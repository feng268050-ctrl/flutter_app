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
  static const defaultEnvironmentTier = CloudEnvironmentTier.test;

  final String preferencePath;

  CloudEnvironmentTier _environmentTier = defaultEnvironmentTier;
  bool _warmed = false;

  CloudEnvironmentTier get environmentTier => _environmentTier;

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
      _environmentTier = defaultEnvironmentTier;
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
    await _writeUnlocked();
    notifyListeners();
  }

  void _applyJson(String raw) {
    _environmentTier = defaultEnvironmentTier;
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
    } catch (e) {
      debugPrint('cloud-settings: corrupt JSON, using defaults: $e');
      _environmentTier = defaultEnvironmentTier;
    }
  }

  Map<String, dynamic> _toJson() => {
        keyEnvironmentTier: _environmentTier.wireName,
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
