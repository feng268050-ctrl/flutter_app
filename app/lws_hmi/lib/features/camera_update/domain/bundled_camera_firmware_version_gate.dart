/// Pure SemVer+build gate for App-bundled camera firmware ZIPs.
///
/// Filename: `{MODEL}-v{SEMVER} build{YYYYMMDD}.zip`
/// Device `appVersion`: `v1.0.5 build20251127` (optional leading `v`/`V`).
final class CameraFirmwareVersion {
  const CameraFirmwareVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
    this.model,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;
  final String? model;

  (int, int, int) get semver => (major, minor, patch);

  String get displaySemVer => '$major.$minor.$patch';

  String get label => 'v$displaySemVer build$build';

  int compareTo(CameraFirmwareVersion other) {
    final sem = _compareTriple(semver, other.semver);
    if (sem != 0) {
      return sem;
    }
    return build.compareTo(other.build);
  }

  bool operator >(CameraFirmwareVersion other) => compareTo(other) > 0;

  static int _compareTriple((int, int, int) a, (int, int, int) b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    return a.$3.compareTo(b.$3);
  }
}

/// Filename / `appVersion` parse + upgrade candidate gate.
abstract final class BundledCameraFirmwareVersionGate {
  /// `{MODEL}-vX.Y.Z buildYYYYMMDD.zip` (space before `build`).
  static final RegExp filePattern = RegExp(
    r'^([A-Za-z0-9]+)-v(\d+)\.(\d+)\.(\d+) build(\d{8})\.zip$',
    caseSensitive: false,
  );

  /// Live/device `appVersion` like `v1.0.5 build20251127`.
  static final RegExp appVersionPattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:\s+build(\d{8}))?$',
    caseSensitive: false,
  );

  static bool isValidFirmwareFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return false;
    }
    return filePattern.hasMatch(fileName);
  }

  static CameraFirmwareVersion? parseFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return null;
    }
    final m = filePattern.firstMatch(fileName);
    if (m == null) {
      return null;
    }
    return CameraFirmwareVersion(
      model: m.group(1)!.toUpperCase(),
      major: int.parse(m.group(2)!),
      minor: int.parse(m.group(3)!),
      patch: int.parse(m.group(4)!),
      build: int.parse(m.group(5)!),
    );
  }

  /// Parses deviceinfo `appVersion` / `app_version` (build optional → 0).
  static CameraFirmwareVersion? parseAppVersion(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final m = appVersionPattern.firstMatch(trimmed);
    if (m == null) {
      return null;
    }
    final buildRaw = m.group(4);
    return CameraFirmwareVersion(
      major: int.parse(m.group(1)!),
      minor: int.parse(m.group(2)!),
      patch: int.parse(m.group(3)!),
      build: buildRaw == null ? 0 : int.parse(buildRaw),
    );
  }

  /// True when bundled (SemVer, build) is strictly greater than device.
  static bool isUpgradeCandidate({
    required String bundledFileName,
    required String? deviceAppVersionRaw,
  }) {
    final bundled = parseFileName(bundledFileName);
    final device = parseAppVersion(deviceAppVersionRaw);
    if (bundled == null || device == null) {
      return false;
    }
    return bundled > device;
  }
}
