import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';
import 'package:lws_hmi/features/camera_update/infrastructure/bundled_camera_firmware_assets.dart';

/// Offline camera program check: bundled ZIP SemVer+build strictly newer.
///
/// Does not talk HTTP — caller supplies live [deviceAppVersionRaw] from
/// [CameraDeviceInfoCache] (null / unparsable → unavailable).
class CameraProgramUpgradeChecker implements UpgradeChecker {
  CameraProgramUpgradeChecker({
    required this.deviceAppVersionRaw,
    this.assetFileNames,
  });

  /// Raw `appVersion` from deviceinfo, or null when unreachable.
  final String? deviceAppVersionRaw;

  /// Discoverable `.zip` names; when null, loads from App assets.
  final List<String>? assetFileNames;

  static const UpgradeChannel channel = UpgradeChannel.cameraProgram;

  @override
  Future<UpgradeCheckResult> check({
    required String currentVersion,
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    if (!shouldRunVersionCheck(policy)) {
      return const UpgradeCheckUnavailable(
        reason: 'camera program version check skipped by policy',
      );
    }
    if (deviceAppVersionRaw == null || deviceAppVersionRaw!.trim().isEmpty) {
      return const UpgradeCheckUnavailable(reason: 'camera unreachable');
    }
    final device = BundledCameraFirmwareVersionGate.parseAppVersion(
      deviceAppVersionRaw,
    );
    if (device == null) {
      return const UpgradeCheckUnavailable(
        reason: 'camera appVersion unparsable',
      );
    }

    final names = assetFileNames ??
        await BundledCameraFirmwareAssets.listFirmwareFileNames();
    final selected = BundledCameraFirmwareAssets.selectLatestFileName(names);
    if (selected == null) {
      return const UpgradeCheckUpToDate();
    }
    if (!BundledCameraFirmwareVersionGate.isUpgradeCandidate(
      bundledFileName: selected,
      deviceAppVersionRaw: deviceAppVersionRaw,
    )) {
      return const UpgradeCheckUpToDate();
    }

    final bundled =
        BundledCameraFirmwareVersionGate.parseFileName(selected)!;
    return UpgradeCheckAvailable(
      UpgradeOffer(
        channel: channel,
        version: bundled.label,
        currentVersion: currentVersion,
        payload: selected,
      ),
    );
  }
}
