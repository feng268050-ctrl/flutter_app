/// Cloud OTA manifest (version + archive URLs).
final class OtaManifest {
  const OtaManifest({
    required this.version,
    required this.packageUrl,
    this.sigUrl,
    this.sha512,
  });

  final String version;
  final String packageUrl;
  final String? sigUrl;
  final String? sha512;

  /// Resolved signature URL: explicit [sigUrl] or [packageUrl] + `.sig`.
  String get sigUrlResolved => sigUrl ?? '$packageUrl.sig';

  factory OtaManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final packageUrl = json['package_url'];
    if (version is! String || version.isEmpty) {
      throw FormatException('manifest missing version', json);
    }
    if (packageUrl is! String || packageUrl.isEmpty) {
      throw FormatException('manifest missing package_url', json);
    }
    return OtaManifest(
      version: version,
      packageUrl: packageUrl,
      sigUrl: json['sig_url'] as String?,
      sha512: json['sha512'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'package_url': packageUrl,
        if (sigUrl != null) 'sig_url': sigUrl,
        if (sha512 != null) 'sha512': sha512,
      };
}
