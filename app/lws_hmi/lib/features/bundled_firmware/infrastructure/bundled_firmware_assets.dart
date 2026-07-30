import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';

/// Discovers ship-tree `assets/.generated/firmware/control-board/LSW01H*.bin`
/// (from prepare) and picks the newest SW.
abstract final class BundledFirmwareAssets {
  /// Ship tree from `make prepare-app-assets` (newest SW per HW).
  static const assetPrefix = 'assets/.generated/firmware/control-board/';

  /// Returns the asset key for the newest valid bin, or null if none.
  ///
  /// When [deviceHw] is set, only bins with that hardware version are considered,
  /// then the highest software version wins. Without [deviceHw], the highest SW
  /// among all valid names is selected.
  static Future<String?> discoverAssetKey({
    AssetBundle? bundle,
    int? deviceHw,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final names = await listFirmwareFileNames(bundle: assetBundle);
    final selected = selectLatestFileName(names, deviceHw: deviceHw);
    if (selected == null) {
      return null;
    }
    return '$assetPrefix$selected';
  }

  /// Picks the newest SW among [names]; optionally filter by [deviceHw].
  static String? selectLatestFileName(
    Iterable<String> names, {
    int? deviceHw,
  }) {
    String? best;
    var bestSw = -1;
    for (final name in names) {
      if (!BundledFirmwareVersionGate.isValidFirmwareFileName(name)) {
        continue;
      }
      final hw = BundledFirmwareVersionGate.hardwareVersion(name);
      final sw = BundledFirmwareVersionGate.softwareVersion(name);
      if (hw == null || sw == null) {
        continue;
      }
      if (deviceHw != null && hw != deviceHw) {
        continue;
      }
      if (sw > bestSw) {
        bestSw = sw;
        best = name;
      }
    }
    return best;
  }

  /// Valid basename list under [assetPrefix] (may be empty or >1).
  static Future<List<String>> listFirmwareFileNames({
    AssetBundle? bundle,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(assetBundle);
      final keys = manifest
          .listAssets()
          .where((k) => k.startsWith(assetPrefix) && k.endsWith('.bin'))
          .toList(growable: false);
      final names = <String>[];
      for (final key in keys) {
        final name = key.substring(assetPrefix.length);
        if (name.contains('/')) {
          continue;
        }
        if (!BundledFirmwareVersionGate.isValidFirmwareFileName(name)) {
          debugPrint('BundledFirmwareAssets: skip invalid name $name');
          continue;
        }
        names.add(name);
      }
      return names;
    } catch (e) {
      debugPrint('BundledFirmwareAssets: list failed: $e');
      return const [];
    }
  }

  static Future<ByteData?> loadBytes(
    String assetKey, {
    AssetBundle? bundle,
  }) async {
    try {
      return await (bundle ?? rootBundle).load(assetKey);
    } catch (e) {
      debugPrint('BundledFirmwareAssets: load $assetKey failed: $e');
      return null;
    }
  }
}
