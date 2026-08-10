import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';

/// Resolves HMI app channel manifests from the public R2 CDN (always
/// `release.json`). Cloud-only — no bundled HMI package version.
abstract final class HmiAppManifestUrl {
  static const channel = 'app';

  /// `{cdn}/{artifact}/app/release.json` (default artifact `lws-hmi`).
  static String resolve({String artifact = OtaManifestUrl.defaultArtifact}) {
    final a = artifact.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final slug = a.isEmpty ? OtaManifestUrl.defaultArtifact : a;
    return '${OtaManifestUrl.cdnBase}/$slug/$channel/${OtaManifestUrl.channelFile}';
  }
}
