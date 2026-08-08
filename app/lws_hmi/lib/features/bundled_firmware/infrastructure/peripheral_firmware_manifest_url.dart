import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';

/// Resolves peripheral firmware channel manifests from the public R2 CDN
/// (always `release.json`).
abstract final class PeripheralFirmwareManifestUrl {
  static const controlBoardChannel = 'control-board';
  static const cameraChannel = 'camera';

  /// `{cdn}/{artifact}/{channel}/release.json`
  static String resolve({
    required String channel,
    String artifact = OtaManifestUrl.defaultArtifact,
  }) {
    final a = artifact.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final slug = a.isEmpty ? OtaManifestUrl.defaultArtifact : a;
    final c = channel.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return '${OtaManifestUrl.cdnBase}/$slug/$c/release.json';
  }

  static String resolveControlBoard({
    String artifact = OtaManifestUrl.defaultArtifact,
  }) {
    return resolve(channel: controlBoardChannel, artifact: artifact);
  }

  static String resolveCamera({
    String artifact = OtaManifestUrl.defaultArtifact,
  }) {
    return resolve(channel: cameraChannel, artifact: artifact);
  }
}
