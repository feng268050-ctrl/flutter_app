import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:flutter/foundation.dart';

/// Worker / cloud API environment tier (shared across Apps).
enum CloudEnvironmentTier {
  /// Test Worker.
  test,

  /// Production Worker (default).
  prod,
}

extension CloudEnvironmentTierCodec on CloudEnvironmentTier {
  String get wireName => name;

  static CloudEnvironmentTier parse(
    String? raw, {
    CloudEnvironmentTier fallback = CloudEnvironmentTier.prod,
  }) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return CloudEnvironmentTier.prod;
      case 'test':
        return CloudEnvironmentTier.test;
      case 'dev':
      case 'debug':
        return CloudEnvironmentTier.prod;
      default:
        return fallback;
    }
  }
}

const kCloudEnvironmentTiers = <CloudEnvironmentTier>[
  CloudEnvironmentTier.prod,
  CloudEnvironmentTier.test,
];

/// Platform cloud-API env prefs under `/var/lib/network/` (with proxy / primary).
///
/// Not App-owned: OS Settings, product HMI, and future Apps share this file.
abstract final class CloudEnvironmentPrefs {
  static const confPath = '/var/lib/network/cloud.conf';
  static const keyEnvironmentTier = 'environment_tier';

  /// Pre-network path (HMI JSON). Read once for migration only.
  static const legacyJsonPath = '/var/lib/hmi/cloud-settings.json';
  static const legacyJsonKeyEnvironmentTier = 'environmentTier';

  static CloudEnvironmentTier readSync([String path = confPath]) {
    final map = readKeyValueConfFileSync(path);
    final raw = map[keyEnvironmentTier];
    if (raw == null || raw.trim().isEmpty) {
      return CloudEnvironmentTier.prod;
    }
    return CloudEnvironmentTierCodec.parse(raw);
  }

  static Future<CloudEnvironmentTier> read([String path = confPath]) async {
    final map = await readKeyValueConfFile(path);
    final raw = map[keyEnvironmentTier];
    if (raw == null || raw.trim().isEmpty) {
      return CloudEnvironmentTier.prod;
    }
    return CloudEnvironmentTierCodec.parse(raw);
  }

  static Future<void> write(
    CloudEnvironmentTier tier, [
    String path = confPath,
  ]) {
    return upsertKeyValueConfFile(path, {keyEnvironmentTier: tier.wireName});
  }

  /// Prefer [confPath]; if missing, copy `environmentTier` from legacy HMI JSON.
  static Future<CloudEnvironmentTier> readOrMigrate({
    String conf = confPath,
    String legacyJson = legacyJsonPath,
  }) async {
    final confFile = File(conf);
    if (await confFile.exists()) {
      return read(conf);
    }
    final legacy = await _readLegacyJsonTier(legacyJson);
    if (legacy != null) {
      await write(legacy, conf);
      return legacy;
    }
    return CloudEnvironmentTier.prod;
  }

  static CloudEnvironmentTier readOrMigrateSync({
    String conf = confPath,
    String legacyJson = legacyJsonPath,
  }) {
    final confFile = File(conf);
    if (confFile.existsSync()) {
      return readSync(conf);
    }
    final legacy = _readLegacyJsonTierSync(legacyJson);
    if (legacy != null) {
      // Best-effort sync migrate (warmRead paths).
      try {
        final parent = confFile.parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }
        confFile.writeAsStringSync(
          encodeKeyValueConf({keyEnvironmentTier: legacy.wireName}),
          flush: true,
        );
      } catch (e) {
        debugPrint('cloud-env: sync migrate write failed: $e');
      }
      return legacy;
    }
    return CloudEnvironmentTier.prod;
  }

  static Future<CloudEnvironmentTier?> _readLegacyJsonTier(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) {
        return null;
      }
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) {
        return null;
      }
      final raw = decoded[legacyJsonKeyEnvironmentTier];
      if (raw == null) {
        return null;
      }
      return CloudEnvironmentTierCodec.parse(raw.toString());
    } catch (e) {
      debugPrint('cloud-env: legacy JSON read failed: $e');
      return null;
    }
  }

  static CloudEnvironmentTier? _readLegacyJsonTierSync(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) {
        return null;
      }
      final decoded = jsonDecode(f.readAsStringSync());
      if (decoded is! Map) {
        return null;
      }
      final raw = decoded[legacyJsonKeyEnvironmentTier];
      if (raw == null) {
        return null;
      }
      return CloudEnvironmentTierCodec.parse(raw.toString());
    } catch (e) {
      debugPrint('cloud-env: legacy JSON sync read failed: $e');
      return null;
    }
  }
}
