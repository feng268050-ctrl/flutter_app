import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Resolves peripheral firmware channel manifests (always `release.json`).
abstract final class PeripheralFirmwareManifestUrl {
  static const controlBoardChannel = 'control-board';
  static const cameraChannel = 'camera';

  /// Returns null when cloud services are off or API origin is not pinned.
  static String? resolve({
    required CloudSettingsStore cloudSettings,
    Uri? pinnedApiBase,
    required String channel,
    String artifact = OtaManifestUrl.defaultArtifact,
  }) {
    if (!cloudSettings.cloudServicesEnabled) {
      return null;
    }
    if (pinnedApiBase == null) {
      return null;
    }
    return DeviceApiOriginConfig.joinUnderBase(
      pinnedApiBase,
      '/r2/$artifact/$channel/release.json',
    ).toString();
  }

  static String? resolveControlBoard({
    required CloudSettingsStore cloudSettings,
    Uri? pinnedApiBase,
    String artifact = OtaManifestUrl.defaultArtifact,
  }) {
    return resolve(
      cloudSettings: cloudSettings,
      pinnedApiBase: pinnedApiBase,
      channel: controlBoardChannel,
      artifact: artifact,
    );
  }

  static String? resolveCamera({
    required CloudSettingsStore cloudSettings,
    Uri? pinnedApiBase,
    String artifact = OtaManifestUrl.defaultArtifact,
  }) {
    return resolve(
      cloudSettings: cloudSettings,
      pinnedApiBase: pinnedApiBase,
      channel: cameraChannel,
      artifact: artifact,
    );
  }
}
