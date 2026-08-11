import 'dart:io';

/// Injectable process runner for [LinuxPlatformVersions] (host tests).
typedef PlatformVersionsProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Injectable file reader returning file text or null when missing / unreadable.
typedef PlatformVersionsFileReader = Future<String?> Function(String path);

/// Immutable OS / stack version inventory for OS Settings (read-only probes).
///
/// Each field soft-fails independently: missing or unparseable → null.
/// Never throws out of [LinuxPlatformVersions.snapshot].
final class PlatformVersionsSnapshot {
  const PlatformVersionsSnapshot({
    this.operatingSystem,
    this.osName,
    this.osVersion,
    this.kernelRelease,
    this.selinuxMode,
    this.busyboxVersion,
    this.glibcVersion,
    this.wpaSupplicantVersion,
    this.bluezVersion,
    this.opensslVersion,
    this.opensshVersion,
    this.gstreamerVersion,
    this.flutterVersion,
    this.buildrootVersion,
  });

  /// Display label: prefer `PRETTY_NAME`, else `NAME` + `VERSION`.
  final String? operatingSystem;

  /// `/etc/os-release` `NAME=` (unquoted), when present.
  final String? osName;

  /// `/etc/os-release` `VERSION=` (not `VERSION_ID`), when present.
  final String? osVersion;

  /// `uname -r` / equivalent.
  final String? kernelRelease;

  /// `Disabled` | `Permissive` | `Enforcing`, or null if unknown.
  final String? selinuxMode;

  final String? busyboxVersion;
  final String? glibcVersion;
  final String? wpaSupplicantVersion;
  final String? bluezVersion;
  final String? opensslVersion;
  final String? opensshVersion;
  final String? gstreamerVersion;

  /// Flutter engine / SDK pin from rootfs stamp (e.g. `3.41.9`).
  final String? flutterVersion;

  /// Buildroot pin when baked into os-release or a stamp file.
  final String? buildrootVersion;
}

// --- Pure parsers (unit-tested) --------------------------------------------

/// Unquote a single os-release value (`"Cyber OS"` → `Cyber OS`).
String unquoteOsReleaseValue(String raw) {
  var v = raw.trim();
  if (v.length >= 2 &&
      ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'")))) {
    v = v.substring(1, v.length - 1);
  }
  return v.trim();
}

/// Parse `/etc/os-release` body into a key → unquoted value map.
Map<String, String> parseOsReleaseMap(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final key = trimmed.substring(0, eq).trim();
    if (key.isEmpty) {
      continue;
    }
    out[key] = unquoteOsReleaseValue(trimmed.substring(eq + 1));
  }
  return out;
}

/// Prefer `PRETTY_NAME`, else `NAME` + optional `VERSION`.
String? formatOperatingSystemLabel({
  String? prettyName,
  String? name,
  String? version,
}) {
  final pretty = prettyName?.trim();
  if (pretty != null && pretty.isNotEmpty) {
    return pretty;
  }
  final n = name?.trim();
  final ver = version?.trim();
  if (n != null && n.isNotEmpty) {
    if (ver != null && ver.isNotEmpty) {
      return '$n $ver';
    }
    return n;
  }
  if (ver != null && ver.isNotEmpty) {
    return ver;
  }
  return null;
}

/// Map `/sys/fs/selinux/enforce` (`0`/`1`) → mode label.
String? parseSelinuxEnforceSysfs(String raw) {
  final v = raw.trim();
  if (v == '0') {
    return 'Permissive';
  }
  if (v == '1') {
    return 'Enforcing';
  }
  return null;
}

/// Map `getenforce` stdout → mode label.
String? parseSelinuxGetenforce(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'disabled':
      return 'Disabled';
    case 'permissive':
      return 'Permissive';
    case 'enforcing':
      return 'Enforcing';
    default:
      return null;
  }
}

/// Resolve SELinux UI mode. Missing SELinux fs → `Disabled`.
String? resolveSelinuxMode({
  required bool selinuxFsPresent,
  String? enforceSysfs,
  String? getenforce,
}) {
  if (!selinuxFsPresent) {
    return 'Disabled';
  }
  final fromSysfs = enforceSysfs == null
      ? null
      : parseSelinuxEnforceSysfs(enforceSysfs);
  if (fromSysfs != null) {
    return fromSysfs;
  }
  final fromCmd = getenforce == null ? null : parseSelinuxGetenforce(getenforce);
  if (fromCmd != null) {
    return fromCmd;
  }
  // FS present but unreadable / unknown → treat as Disabled (soft).
  return 'Disabled';
}

/// `BusyBox v1.36.1 (...)` → `1.36.1` (keeps trailing suffix like `1.36.1.git`).
String? parseBusyBoxVersion(String raw) {
  final m = RegExp(
    r'BusyBox\s+v?(\d+\.\d+[\w.\-+]*)',
    caseSensitive: false,
  ).firstMatch(raw);
  return m?.group(1);
}

/// First line of `ldd --version`: `ldd (GNU libc) 2.39` → `2.39`.
String? parseGlibcVersion(String raw) {
  final gnu = RegExp(
    r'ldd\s+\([^)]*\)\s+(\d+\.\d+\S*)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (gnu != null) {
    return gnu.group(1);
  }
  final glibc = RegExp(
    r'(?:GNU\s+libc|GLIBC)\s+(\d+\.\d+\S*)',
    caseSensitive: false,
  ).firstMatch(raw);
  return glibc?.group(1);
}

/// `wpa_supplicant v2.10` → `2.10`.
String? parseWpaSupplicantVersion(String raw) {
  final m = RegExp(
    r'wpa_supplicant\s+v?(\d+\.\d+\S*)',
    caseSensitive: false,
  ).firstMatch(raw);
  return m?.group(1);
}

/// `5.72` or `bluetoothd - BlueZ 5.72` → `5.72`.
String? parseBluezVersion(String raw) {
  final bluez = RegExp(
    r'BlueZ\s+(\d+\.\d+\S*)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (bluez != null) {
    return bluez.group(1);
  }
  final line = raw.trim().split('\n').first.trim();
  final alone = RegExp(r'^(\d+\.\d+\S*)$').firstMatch(line);
  return alone?.group(1);
}

/// `OpenSSL 3.2.0 23 Nov 2023` → `3.2.0`.
String? parseOpensslVersion(String raw) {
  final m = RegExp(r'OpenSSL\s+(\d+\.\d+\.\d+\S*)').firstMatch(raw);
  return m?.group(1);
}

/// `OpenSSH_9.6p1, OpenSSL …` → `9.6p1`.
String? parseOpensshVersion(String raw) {
  final m = RegExp(r'OpenSSH[_ ](\S+?)(?:,|\s|$)').firstMatch(raw);
  return m?.group(1);
}

/// Prefer `GStreamer 1.22.0` line from `gst-inspect-1.0 --version`.
String? parseGstreamerVersion(String raw) {
  final gst = RegExp(r'GStreamer\s+(\d+\.\d+\.\d+\S*)').firstMatch(raw);
  if (gst != null) {
    return gst.group(1);
  }
  final inspect = RegExp(
    r'gst-inspect(?:-1\.0)?\s+version\s+(\d+\.\d+\.\d+\S*)',
    caseSensitive: false,
  ).firstMatch(raw);
  return inspect?.group(1);
}

/// Single-line pin file (`3.41.9` / `2025.02.16`) → trimmed token.
String? parseVersionPinFile(String raw) {
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) {
      continue;
    }
    return t.split(RegExp(r'\s+')).first;
  }
  return null;
}

String _processText(ProcessResult r) {
  final out = r.stdout is String ? r.stdout as String : r.stdout.toString();
  final err = r.stderr is String ? r.stderr as String : r.stderr.toString();
  return '$out\n$err'.trim();
}

/// Linux probes for [PlatformVersionsSnapshot]. Soft-fails each field.
final class LinuxPlatformVersions {
  LinuxPlatformVersions({
    this.osReleasePath = '/etc/os-release',
    this.selinuxEnforcePath = '/sys/fs/selinux/enforce',
    this.flutterEngineVersionPath =
        '/usr/share/flutter/flutter-engine.version',
    this.flutterSdkVersionPath = '/usr/share/flutter/flutter-sdk.version',
    this.buildrootStampPaths = const <String>[
      '/etc/buildroot-version',
      '/usr/share/buildroot/BUILDROOT_VERSION',
      '/etc/buildroot/BUILDROOT_VERSION',
    ],
    this.gstreamerPinPaths = const <String>[
      '/usr/share/gstreamer-1.0/version',
      '/etc/gstreamer.version',
    ],
    PlatformVersionsProcessRunner? runProcess,
    PlatformVersionsFileReader? readFile,
    Future<bool> Function(String path)? pathExists,
  })  : _run = runProcess ?? ((exe, args) => Process.run(exe, args)),
        _readFile = readFile ?? _defaultReadFile,
        _pathExists = pathExists ?? _defaultPathExists;

  final String osReleasePath;
  final String selinuxEnforcePath;
  final String flutterEngineVersionPath;
  final String flutterSdkVersionPath;
  final List<String> buildrootStampPaths;
  final List<String> gstreamerPinPaths;

  final PlatformVersionsProcessRunner _run;
  final PlatformVersionsFileReader _readFile;
  final Future<bool> Function(String path) _pathExists;

  static Future<String?> _defaultReadFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) {
        return null;
      }
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _defaultPathExists(String path) async {
    try {
      return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
    } catch (_) {
      return false;
    }
  }

  /// Collect all probes. Never throws.
  Future<PlatformVersionsSnapshot> snapshot() async {
    try {
      final osMap = await _readOsRelease();
      final osName = _nonEmpty(osMap['NAME']);
      final osVersion = _nonEmpty(osMap['VERSION']);
      final pretty = _nonEmpty(osMap['PRETTY_NAME']);
      return PlatformVersionsSnapshot(
        operatingSystem: formatOperatingSystemLabel(
          prettyName: pretty,
          name: osName,
          version: osVersion,
        ),
        osName: osName,
        osVersion: osVersion,
        kernelRelease: await _readKernelRelease(),
        selinuxMode: await _readSelinuxMode(),
        busyboxVersion: await _probe(
          parseBusyBoxVersion,
          const [
            ('busybox', <String>[]),
          ],
        ),
        glibcVersion: await _probe(
          parseGlibcVersion,
          const [
            ('ldd', <String>['--version']),
          ],
        ),
        wpaSupplicantVersion: await _probe(
          parseWpaSupplicantVersion,
          const [
            ('wpa_supplicant', <String>['-v']),
          ],
        ),
        bluezVersion: await _probe(
          parseBluezVersion,
          const [
            ('bluetoothd', <String>['-v']),
            ('bluetoothctl', <String>['--version']),
          ],
        ),
        opensslVersion: await _probe(
          parseOpensslVersion,
          const [
            ('openssl', <String>['version']),
          ],
        ),
        opensshVersion: await _probe(
          parseOpensshVersion,
          const [
            ('sshd', <String>['-V']),
            ('ssh', <String>['-V']),
          ],
        ),
        gstreamerVersion: await _readGstreamerVersion(),
        flutterVersion: await _readFlutterVersion(),
        buildrootVersion: await _readBuildrootVersion(osMap),
      );
    } catch (_) {
      return const PlatformVersionsSnapshot();
    }
  }

  Future<Map<String, String>> _readOsRelease() async {
    final raw = await _readFile(osReleasePath);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      return parseOsReleaseMap(raw);
    } catch (_) {
      return const {};
    }
  }

  Future<String?> _readKernelRelease() async {
    try {
      final r = await _run('uname', const <String>['-r']);
      final out = _processText(r);
      if (out.isNotEmpty) {
        return out.split('\n').first.trim();
      }
    } catch (_) {}
    try {
      final v = await _readFile('/proc/version');
      if (v == null) {
        return null;
      }
      return RegExp(r'version\s+(\S+)').firstMatch(v)?.group(1);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readSelinuxMode() async {
    try {
      final fsPresent = await _pathExists('/sys/fs/selinux') ||
          await _pathExists(selinuxEnforcePath);
      String? enforce;
      if (fsPresent) {
        enforce = await _readFile(selinuxEnforcePath);
      }
      String? getenforceOut;
      try {
        final r = await _run('getenforce', const <String>[]);
        getenforceOut = _processText(r);
      } catch (_) {}
      return resolveSelinuxMode(
        selinuxFsPresent: fsPresent,
        enforceSysfs: enforce,
        getenforce: getenforceOut,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readGstreamerVersion() async {
    final fromCmd = await _probe(
      parseGstreamerVersion,
      const [
        ('gst-inspect-1.0', <String>['--version']),
        ('gst-inspect', <String>['--version']),
      ],
    );
    if (fromCmd != null) {
      return fromCmd;
    }
    for (final path in gstreamerPinPaths) {
      final pin = parseVersionPinFile(await _readFile(path) ?? '');
      if (pin != null) {
        return pin;
      }
    }
    return null;
  }

  Future<String?> _readFlutterVersion() async {
    for (final path in <String>[
      flutterEngineVersionPath,
      flutterSdkVersionPath,
    ]) {
      final pin = parseVersionPinFile(await _readFile(path) ?? '');
      if (pin != null) {
        return pin;
      }
    }
    return null;
  }

  Future<String?> _readBuildrootVersion(Map<String, String> osMap) async {
    for (final key in <String>[
      'BUILDROOT_VERSION',
      'BUILDROOT',
      'BR2_VERSION',
    ]) {
      final v = _nonEmpty(osMap[key]);
      if (v != null) {
        return v;
      }
    }
    for (final path in buildrootStampPaths) {
      final pin = parseVersionPinFile(await _readFile(path) ?? '');
      if (pin != null) {
        return pin;
      }
    }
    return null;
  }

  Future<String?> _probe(
    String? Function(String raw) parse,
    List<(String, List<String>)> commands,
  ) async {
    for (final cmd in commands) {
      try {
        final r = await _run(cmd.$1, cmd.$2);
        final text = _processText(r);
        if (text.isEmpty) {
          continue;
        }
        final parsed = parse(text);
        if (parsed != null && parsed.isNotEmpty) {
          return parsed;
        }
      } catch (_) {
        // ProcessException / missing binary — try next.
      }
    }
    return null;
  }

  static String? _nonEmpty(String? v) {
    if (v == null) {
      return null;
    }
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
