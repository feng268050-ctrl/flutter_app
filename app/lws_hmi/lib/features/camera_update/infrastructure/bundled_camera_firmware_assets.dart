import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';

/// Discovers ship-tree `assets/.generated/firmware/camera/*.zip` (from prepare).
abstract final class BundledCameraFirmwareAssets {
  /// Ship tree from `make prepare-app-assets` (newest package per model).
  static const assetPrefix = 'assets/.generated/firmware/camera/';

  /// Returns the asset key for the newest valid ZIP, or null if none.
  ///
  /// When [model] is set (case-insensitive), only that model is considered.
  static Future<String?> discoverAssetKey({
    AssetBundle? bundle,
    String? model,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final names = await listFirmwareFileNames(bundle: assetBundle);
    final selected = selectLatestFileName(names, model: model);
    if (selected == null) {
      return null;
    }
    return '$assetPrefix$selected';
  }

  /// Picks newest SemVer then build among [names]; optionally filter by [model].
  static String? selectLatestFileName(
    Iterable<String> names, {
    String? model,
  }) {
    final wantModel = model?.trim().toUpperCase();
    String? best;
    CameraFirmwareVersion? bestVer;
    for (final name in names) {
      final ver = BundledCameraFirmwareVersionGate.parseFileName(name);
      if (ver == null) {
        continue;
      }
      if (wantModel != null &&
          wantModel.isNotEmpty &&
          (ver.model ?? '').toUpperCase() != wantModel) {
        continue;
      }
      if (bestVer == null || ver > bestVer) {
        bestVer = ver;
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
          .where((k) => k.startsWith(assetPrefix) && k.endsWith('.zip'))
          .toList(growable: false);
      final names = <String>[];
      for (final key in keys) {
        final name = key.substring(assetPrefix.length);
        if (name.contains('/')) {
          continue;
        }
        if (!BundledCameraFirmwareVersionGate.isValidFirmwareFileName(name)) {
          debugPrint('BundledCameraFirmwareAssets: skip invalid name $name');
          continue;
        }
        names.add(name);
      }
      return names;
    } catch (e) {
      debugPrint('BundledCameraFirmwareAssets: list failed: $e');
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
      debugPrint('BundledCameraFirmwareAssets: load $assetKey failed: $e');
      return null;
    }
  }
}
