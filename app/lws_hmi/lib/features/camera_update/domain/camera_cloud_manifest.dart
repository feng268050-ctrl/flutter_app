import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';

/// Parsed camera cloud channel entry (ZIP filename is typed SoT).
final class CameraCloudCandidate {
  const CameraCloudCandidate({
    required this.fileName,
    required this.packageUrl,
    required this.version,
  });

  final String fileName;
  final String packageUrl;
  final CameraFirmwareVersion version;
}

/// Parse + gate a camera `release.json` object against live device `appVersion`.
///
/// Typed compare uses **filename** SemVer+build, not string compare on channel
/// `version`. Manifest `version` SHOULD be SemVer-only with leading `v`
/// (`v1.0.7`); build stays in `filename`. Mismatches are ignored for gating.
abstract final class CameraCloudManifest {
  static CameraCloudCandidate? tryParseOffer({
    required Map<String, dynamic> json,
    required String? deviceAppVersionRaw,
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
    if (!BundledCameraFirmwareVersionGate.isUpgradeCandidate(
      bundledFileName: fileName,
      deviceAppVersionRaw: deviceAppVersionRaw,
    )) {
      return null;
    }
    final parsed = BundledCameraFirmwareVersionGate.parseFileName(fileName);
    if (parsed == null) {
      return null;
    }
    return CameraCloudCandidate(
      fileName: fileName,
      packageUrl: packageUrl,
      version: parsed,
    );
  }

  /// True when [channelVersion] is SemVer-only matching [expected] (e.g. `v1.0.7`).
  /// Also accepts legacy label (`v1.0.7 build…`) / Maven (`v1.0.7+…`) when SemVer matches.
  static bool channelVersionMatches(
    String channelVersion,
    CameraFirmwareVersion expected,
  ) {
    final fromLabel = BundledCameraFirmwareVersionGate.parseAppVersion(
      channelVersion,
    );
    if (fromLabel != null && fromLabel.semver == expected.semver) {
      return true;
    }
    final fromPlus = _parsePlusBuildVersion(channelVersion);
    if (fromPlus != null && fromPlus.semver == expected.semver) {
      return true;
    }
    final fromSemverOnly = _parseSemVerOnly(channelVersion);
    if (fromSemverOnly != null && fromSemverOnly == expected.semver) {
      return true;
    }
    return false;
  }

  /// Prefer `filename`; else URL-decoded last path segment when it looks like a ZIP.
  static String? _resolveFileName(Map<String, dynamic> json, String packageUrl) {
    final fromField = (json['filename'] as String?)?.trim();
    if (fromField != null &&
        fromField.isNotEmpty &&
        BundledCameraFirmwareVersionGate.isValidFirmwareFileName(fromField)) {
      return fromField;
    }
    final uri = Uri.tryParse(packageUrl);
    if (uri == null || uri.pathSegments.isEmpty) {
      return null;
    }
    final base = Uri.decodeComponent(uri.pathSegments.last);
    if (BundledCameraFirmwareVersionGate.isValidFirmwareFileName(base)) {
      return base;
    }
    return null;
  }

  /// Canonical publish encoding: `v1.0.7` / `1.0.7`.
  static (int, int, int)? _parseSemVerOnly(String raw) {
    final m = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (m == null) {
      return null;
    }
    return (
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  /// Legacy publish encoding: `v1.0.7+20260513` / `1.0.7+20260513`.
  static CameraFirmwareVersion? _parsePlusBuildVersion(String raw) {
    final m = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)\+(\d{8})$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (m == null) {
      return null;
    }
    return CameraFirmwareVersion(
      major: int.parse(m.group(1)!),
      minor: int.parse(m.group(2)!),
      patch: int.parse(m.group(3)!),
      build: int.parse(m.group(4)!),
    );
  }
}
