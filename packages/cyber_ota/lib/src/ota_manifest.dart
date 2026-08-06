/// Cloud OTA manifest (version + archive URLs + optional notes).
final class OtaManifest {
  const OtaManifest({
    required this.version,
    required this.packageUrl,
    this.sigUrl,
    this.sha512,
    this.title,
    this.content,
  });

  final String version;
  final String packageUrl;
  final String? sigUrl;
  final String? sha512;

  /// Optional release title (lws-ui UpgradeActivity).
  final String? title;

  /// Optional release notes body (lws-ui UpgradeActivity).
  final String? content;

  /// Resolved signature URL: explicit [sigUrl] or [packageUrl] + `.sig`.
  String get sigUrlResolved => sigUrl ?? '$packageUrl.sig';

  /// Headline for upgrade UI: manifest [title], else core version, else [version].
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return coreVersion(version) ?? version;
  }

  factory OtaManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! String || version.isEmpty) {
      throw FormatException('manifest missing version', json);
    }
    // Host publish channel JSON uses `url`; internal/WS may use `package_url`.
    final packageUrl = _nonEmptyString(json['package_url']) ??
        _nonEmptyString(json['url']);
    if (packageUrl == null) {
      throw FormatException('manifest missing package_url or url', json);
    }
    return OtaManifest(
      version: version,
      packageUrl: packageUrl,
      sigUrl: _nonEmptyString(json['sig_url']),
      sha512: _nonEmptyString(json['sha512']),
      title: _nonEmptyString(json['title']),
      content: _nonEmptyString(json['content']),
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Drops leading `v` and pre-release / build metadata for UI titles.
  static String? coreVersion(String? raw) {
    if (raw == null) {
      return null;
    }
    var value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    final plus = value.indexOf('+');
    if (plus >= 0) {
      value = value.substring(0, plus);
    }
    final dash = value.indexOf('-');
    if (dash >= 0) {
      value = value.substring(0, dash);
    }
    value = value.trim();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'package_url': packageUrl,
        if (sigUrl != null) 'sig_url': sigUrl,
        if (sha512 != null) 'sha512': sha512,
        if (title != null) 'title': title,
        if (content != null) 'content': content,
      };
}
