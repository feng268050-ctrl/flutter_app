/// Resolves whole-device OTA channel manifests from the public R2 CDN.
///
/// Always **`release.json`**. Independent of cloud services, environment tier,
/// and Worker `/r2/` / pinned API origin.
abstract final class OtaManifestUrl {
  static const defaultArtifact = 'lws-hmi';
  static const channelFile = 'release.json';

  /// Public CDN origin for published OTA / peripheral firmware objects.
  static const cdnBase = 'https://cdn.lasercyber.com';

  /// `{cdnBase}/{artifact}/release.json` (default artifact `lws-hmi`).
  static String resolve({String artifact = defaultArtifact}) {
    final a = artifact.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final slug = a.isEmpty ? defaultArtifact : a;
    return '$cdnBase/$slug/$channelFile';
  }
}
