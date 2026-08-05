import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Resolves the whole-device OTA manifest URL from cloud settings + pinned API.
abstract final class OtaManifestUrl {
  static const defaultArtifact = 'lws-hmi';

  /// Returns null when cloud OTA check is not configured (no URL — not a false success).
  static String? resolve({
    required CloudSettingsStore cloudSettings,
    Uri? pinnedApiBase,
    String artifact = defaultArtifact,
  }) {
    if (!cloudSettings.cloudServicesEnabled) {
      return null;
    }
    if (pinnedApiBase == null) {
      return null;
    }
    final channelFile = switch (cloudSettings.environmentTier) {
      CloudEnvironmentTier.prod => 'release.json',
      CloudEnvironmentTier.dev || CloudEnvironmentTier.test => 'staging.json',
    };
    return DeviceApiOriginConfig.joinUnderBase(
      pinnedApiBase,
      '/view/$artifact/$channelFile',
    ).toString();
  }
}
