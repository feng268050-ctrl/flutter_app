import 'dart:io';

import 'package:cyber_hal/src/sys_info/sys_info.dart';

/// Default on-device product identity file (`VAR_HMI` → `/userdata/hmi`).
const String kProductIniPath = '/var/lib/hmi/product.ini';

/// Parses flat `key=value` product.ini (comments / blanks ignored).
final class ProductIniReader {
  const ProductIniReader({this.path = kProductIniPath});

  final String path;

  /// Returns a map of trimmed keys → trimmed values. Missing file → empty map.
  Future<Map<String, String>> read() async {
    try {
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
      final value = line.substring(eq + 1).trim();
      if (key.isEmpty) {
        continue;
      }
      out[key] = value;
    }
    return out;
  }
}

/// Factory product identity + tunables from [product.ini](kProductIniPath).
///
/// Built-in fields are class properties; extended keys use accessors. Missing
/// keys are empty strings (UI maps empty → `-`).
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

  /// Factory `sn` from ini, else [chipId]; empty if both unavailable.
  final String sn;

  /// Chip / SoC serial (DT or `/proc/cpuinfo`); never from product.ini `sn`.
  final String chipId;

  final Map<String, String> _keys;

  String get(String key) => (_keys[key] ?? '').trim();

  String cameraIp() => get('camera_ip');

  /// Typed: only `1` or `2`; otherwise empty.
  String cameraType() {
    final v = get('camera_type');
    return (v == '1' || v == '2') ? v : '';
  }

  String focusScaleRef() => get('focus_scale_ref');

  /// Typed: only `slide_window` or `immediate`; otherwise empty.
  String controlCardCommAlarmMode() {
    final v = get('control_card_comm_alarm_mode');
    return (v == 'slide_window' || v == 'immediate') ? v : '';
  }

  /// Load from [path]; [sn] prefers ini, else [chipId].
  static Future<ProductInfo> load({
    String path = kProductIniPath,
    DeviceSnReader deviceSnReader = const DeviceSnReader(),
    Map<String, String>? keysOverride,
  }) async {
    final keys = keysOverride ?? await ProductIniReader(path: path).read();
    final brand = (keys['brand'] ?? '').trim();
    final model = (keys['model'] ?? '').trim();
    final iniSn = (keys['sn'] ?? '').trim();

    var chipId = '';
    final chip = await deviceSnReader.readChipId();
    if (chip != deviceSnReader.unavailableDisplay && chip.trim().isNotEmpty) {
      chipId = chip.trim();
    }

    final sn = iniSn.isNotEmpty ? iniSn : chipId;
    return ProductInfo(
      brand: brand,
      model: model,
      sn: sn,
      chipId: chipId,
      keys: keys,
    );
  }
}
