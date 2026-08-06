import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Resolves the whole-device OTA manifest URL from cloud settings + pinned API.
///
/// Prefer Worker **`/r2/{artifact}/{channel}.json`** until api-server allowlists
/// `lws-hmi` on **`GET /view/...`** (today `/view/lws-hmi/...` returns
/// `ROUTE_NOT_FOUND` while published objects are readable under `/r2/`).
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
    // `/r2/` streams APP_BUCKET keys without the static-library view allowlist.
    return DeviceApiOriginConfig.joinUnderBase(
      pinnedApiBase,
      '/r2/$artifact/$channelFile',
    ).toString();
  }

  /// Canonical `/view/` URL (lws-ui shape). Use when Worker includes HMI artifacts.
  static String? resolveView({
    required CloudSettingsStore cloudSettings,
    Uri? pinnedApiBase,
    String artifact = defaultArtifact,
  }) {
    if (!cloudSettings.cloudServicesEnabled || pinnedApiBase == null) {
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
