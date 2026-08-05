import 'dart:io';

import 'package:cyber_hal/src/sys_info/sys_info.dart';

/// Default on-device properties file (`VAR_HAL` → `/userdata/hal`).
const String kPropertiesIniPath = '/var/lib/hal/properties.ini';

/// @nodoc Legacy alias — prefer [kPropertiesIniPath].
const String kProductIniPath = kPropertiesIniPath;

/// Default on-device helper for Vendor Storage brand/model/sn.
const String kReadProductIdentityPath = '/usr/bin/read-identity';

/// One-shot rename of legacy `product.ini` → `properties.ini` when needed.
Future<void> migrateLegacyProductIniBasename(String propertiesPath) async {
  try {
    final props = File(propertiesPath);
    if (await props.exists()) {
      return;
    }
    final dir = props.parent.path;
    final legacy = File('$dir/product.ini');
    if (!await legacy.exists()) {
      return;
    }
    await legacy.rename(propertiesPath);
  } catch (_) {
    // Best-effort; bind-prefs / host tools also migrate.
  }
}

/// Parses flat `key=value` properties.ini (comments / blanks ignored).
final class ProductIniReader {
  const ProductIniReader({this.path = kPropertiesIniPath});

  final String path;

  /// Returns a map of trimmed keys → trimmed values. Missing file → empty map.
  Future<Map<String, String>> read() async {
    try {
      await migrateLegacyProductIniBasename(path);
      final file = File(path);
      if (!await file.exists()) {
        return const {};
      }
      return parse(await file.readAsString());
    } catch (_) {
      return const {};
    }
  }

  /// Sync parse for tests / host tools that already have file contents.
  static Map<String, String> parse(String contents) {
    final out = <String, String>{};
    for (final raw in contents.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      final key = line.substring(0, eq).trim();
      final value = _normalizeValue(line.substring(eq + 1).trim());
      if (key.isEmpty) {
        continue;
      }
      out[key] = value;
    }
    return out;
  }

  static String _normalizeValue(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      final matchingQuotes =
          (first == '"' && last == '"') || (first == "'" && last == "'");
      if (matchingQuotes) {
        return value.substring(1, value.length - 1).trim();
      }
    }
    return value;
  }
}

/// Reads brand / model / sn from Vendor Storage via board helper.
class VendorIdentityReader {
  const VendorIdentityReader({
    this.readIdentityPath = kReadProductIdentityPath,
  });

  final String readIdentityPath;

  Future<String> readBrand() => _run('brand');

  Future<String> readModel() => _run('model');

  Future<String> readSn() => _run('sn');

  Future<String> _run(String field) async {
    try {
      final result = await Process.run(readIdentityPath, <String>[field]);
      if (result.exitCode != 0) {
        return '';
      }
      final out = (result.stdout is String)
          ? result.stdout as String
          : result.stdout.toString();
      return out.trim();
    } catch (_) {
      return '';
    }
  }
}

/// Product identity (Vendor Storage) + opaque properties bag from [properties.ini].
///
/// **Built-in (known to HAL):** [brand], [model], [sn], [chipId] — identity only.
/// **Everything else** is an unknown string key via [get]; HAL does not interpret
/// product tunables such as `camera_ip` / `camera_type` / etc. Product Apps own
/// key names, typing, and defaults.
///
/// Stale `brand` / `model` / `sn` lines in properties.ini are ignored for identity.
final class ProductInfo {
  const ProductInfo({
    this.brand = '',
    this.model = '',
    this.sn = '',
    this.chipId = '',
    Map<String, String> keys = const {},
  }) : _keys = keys;

  /// Empty identity (no file / stub).
  static const empty = ProductInfo();

  final String brand;
  final String model;

  /// Vendor Storage SN, else [chipId]; empty if both unavailable.
  final String sn;

  /// Chip / SoC serial (DT or `/proc/cpuinfo`); never from properties.ini `sn`.
  final String chipId;

  final Map<String, String> _keys;

  /// Opaque property from properties.ini (or empty). HAL does not know key semantics.
  String get(String key) => (_keys[key] ?? '').trim();

  /// Load opaque properties from [path]; identity from Vendor Storage (not ini keys).
  ///
  /// [identityOverride] supplies brand/model/sn for tests (skips helper).
  static Future<ProductInfo> load({
    String path = kPropertiesIniPath,
    DeviceSnReader deviceSnReader = const DeviceSnReader(),
    VendorIdentityReader vendorIdentityReader = const VendorIdentityReader(),
    Map<String, String>? keysOverride,
    Map<String, String>? identityOverride,
  }) async {
    final keys = keysOverride ?? await ProductIniReader(path: path).read();

    var chipId = '';
    final chip = await deviceSnReader.readChipId();
    if (chip != deviceSnReader.unavailableDisplay && chip.trim().isNotEmpty) {
      chipId = chip.trim();
    }

    late final String brand;
    late final String model;
    late final String sn;
    if (identityOverride != null) {
      brand = (identityOverride['brand'] ?? '').trim();
      model = (identityOverride['model'] ?? '').trim();
      final overrideSn = (identityOverride['sn'] ?? '').trim();
      sn = overrideSn.isNotEmpty ? overrideSn : chipId;
    } else {
      brand = (await vendorIdentityReader.readBrand()).trim();
      model = (await vendorIdentityReader.readModel()).trim();
      // read-serial applies Vendor Storage → chip-ID fallback (same as make devices).
      final productSn = await deviceSnReader.read();
      if (productSn != deviceSnReader.unavailableDisplay &&
          productSn.trim().isNotEmpty) {
        sn = productSn.trim();
      } else {
        sn = chipId;
      }
    }

    return ProductInfo(
      brand: brand,
      model: model,
      sn: sn,
      chipId: chipId,
      keys: keys,
    );
  }
}
