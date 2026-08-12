import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';

/// Parsed control-board cloud channel entry (filename is typed SoT).
final class ControlBoardCloudCandidate {
  const ControlBoardCloudCandidate({
    required this.fileName,
    required this.packageUrl,
    required this.hardwareVersion,
    required this.softwareVersion,
    this.title,
    this.content,
  });

  final String fileName;
  final String packageUrl;
  final int hardwareVersion;
  final int softwareVersion;

  /// Optional release title from `release.json` (preferred UI headline).
  final String? title;

  /// Optional release notes body from `release.json` (preferred UI body).
  final String? content;
}

/// Parse + gate a control-board `release.json` object against live device HW/SW.
///
/// Typed compare uses **filename** (`LSW01H####S####.bin`), not semver on the
/// channel `version` string. Manifest `version` (bare SW, e.g. `1017`) is
/// optional consistency metadata only.
abstract final class ControlBoardCloudManifest {
  /// Returns a candidate when [json] names a HW-matching bin strictly newer
  /// than [deviceSw]; otherwise null (soft no-update / incompatible).
  static ControlBoardCloudCandidate? tryParseOffer({
    required Map<String, dynamic> json,
    required int deviceHw,
    required int deviceSw,
  }) {
    final packageUrl = ((json['url'] ?? json['package_url']) as String?)
        ?.trim();
    if (packageUrl == null || packageUrl.isEmpty) {
      return null;
    }

    final fileName = _resolveFileName(json, packageUrl);
    if (fileName == null) {
      return null;
    }
    if (!BundledFirmwareVersionGate.isUpgradeCandidate(
      bundledFileName: fileName,
      deviceHw: deviceHw,
      deviceSw: deviceSw,
    )) {
      return null;
    }
    final hw = BundledFirmwareVersionGate.hardwareVersion(fileName);
    final sw = BundledFirmwareVersionGate.softwareVersion(fileName);
    if (hw == null || sw == null) {
      return null;
    }

    // Optional: channel version should be bare {SW} (ignore mismatch — filename wins).
    final channelVersion = (json['version'] as String?)?.trim();
    if (channelVersion != null &&
        channelVersion.isNotEmpty &&
        !_channelVersionMatchesSw(channelVersion, sw)) {
      // Keep offer; callers may log. Filename remains authority.
    }

    return ControlBoardCloudCandidate(
      fileName: fileName,
      packageUrl: packageUrl,
      hardwareVersion: hw,
      softwareVersion: sw,
      title: _optionalNote(json, 'title'),
      content: _optionalNote(json, 'content'),
    );
  }

  static String? _optionalNote(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Prefer `filename`; else last path segment of package URL when it looks like a bin.
  static String? _resolveFileName(Map<String, dynamic> json, String packageUrl) {
    final fromField = (json['filename'] as String?)?.trim();
    if (fromField != null &&
        fromField.isNotEmpty &&
        BundledFirmwareVersionGate.isValidFirmwareFileName(fromField)) {
      return fromField;
    }
    final uri = Uri.tryParse(packageUrl);
    if (uri == null || uri.pathSegments.isEmpty) {
      return null;
    }
    final base = Uri.decodeComponent(uri.pathSegments.last);
    if (BundledFirmwareVersionGate.isValidFirmwareFileName(base)) {
      return base;
    }
    return null;
  }

  /// True when [channelVersion] is bare `{sw}` or optional legacy `v{sw}` / `V{sw}`.
  static bool channelVersionMatchesSw(String channelVersion, int sw) =>
      _channelVersionMatchesSw(channelVersion, sw);

  static bool _channelVersionMatchesSw(String channelVersion, int sw) {
    var v = channelVersion.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    // Reject full basename accidentally published as version (LSW01H…).
    if (v.toUpperCase().startsWith('LSW')) {
      return false;
    }
    final parsed = int.tryParse(v);
    return parsed == sw;
  }
}
