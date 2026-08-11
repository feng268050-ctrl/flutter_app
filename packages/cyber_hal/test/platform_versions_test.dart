import 'dart:io';

import 'package:cyber_hal/secrets.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('os-release parsers', () {
    test('parseOsReleaseMap unquotes NAME/PRETTY/VERSION', () {
      const raw = '''
NAME="Cyber OS"
ID=cyberos
VERSION="1.0.0"
VERSION_ID=1.0
PRETTY_NAME="Cyber OS 1.0.0"
BUILDROOT_VERSION="2025.02.16"
''';
      final m = parseOsReleaseMap(raw);
      expect(m['NAME'], 'Cyber OS');
      expect(m['VERSION'], '1.0.0');
      expect(m['PRETTY_NAME'], 'Cyber OS 1.0.0');
      expect(m['BUILDROOT_VERSION'], '2025.02.16');
    });

    test('formatOperatingSystemLabel prefers PRETTY_NAME', () {
      expect(
        formatOperatingSystemLabel(
          prettyName: 'Cyber OS 1.0.0',
          name: 'Cyber OS',
          version: '1.0.0',
        ),
        'Cyber OS 1.0.0',
      );
      expect(
        formatOperatingSystemLabel(name: 'Cyber OS', version: '1.2.3'),
        'Cyber OS 1.2.3',
      );
      expect(formatOperatingSystemLabel(), isNull);
    });
  });

  group('SELinux parsers', () {
    test('parseSelinuxEnforceSysfs', () {
      expect(parseSelinuxEnforceSysfs('0\n'), 'Permissive');
      expect(parseSelinuxEnforceSysfs('1'), 'Enforcing');
      expect(parseSelinuxEnforceSysfs('x'), isNull);
    });

    test('parseSelinuxGetenforce', () {
      expect(parseSelinuxGetenforce('Disabled'), 'Disabled');
      expect(parseSelinuxGetenforce('permissive'), 'Permissive');
      expect(parseSelinuxGetenforce('Enforcing\n'), 'Enforcing');
      expect(parseSelinuxGetenforce('???'), isNull);
    });

    test('resolveSelinuxMode soft-fails to Disabled when fs absent', () {
      expect(
        resolveSelinuxMode(selinuxFsPresent: false),
        'Disabled',
      );
      expect(
        resolveSelinuxMode(selinuxFsPresent: true, enforceSysfs: '0'),
        'Permissive',
      );
      expect(
        resolveSelinuxMode(
          selinuxFsPresent: true,
          getenforce: 'Enforcing',
        ),
        'Enforcing',
      );
    });
  });

  group('version string parsers', () {
    test('parseBusyBoxVersion', () {
      expect(
        parseBusyBoxVersion(
          'BusyBox v1.36.1 (2024-01-01) multi-call binary.\nUsage:',
        ),
        '1.36.1',
      );
      expect(parseBusyBoxVersion('not busybox'), isNull);
    });

    test('parseGlibcVersion', () {
      expect(
        parseGlibcVersion(
          'ldd (GNU libc) 2.39\nCopyright (C) 2024 Free Software Foundation\n',
        ),
        '2.39',
      );
      expect(parseGlibcVersion(''), isNull);
    });

    test('parseWpaSupplicantVersion', () {
      expect(parseWpaSupplicantVersion('wpa_supplicant v2.10\n'), '2.10');
      expect(parseWpaSupplicantVersion('nope'), isNull);
    });

    test('parseBluezVersion', () {
      expect(parseBluezVersion('5.72\n'), '5.72');
      expect(parseBluezVersion('bluetoothd - BlueZ 5.66'), '5.66');
      expect(parseBluezVersion(''), isNull);
    });

    test('parseOpensslVersion', () {
      expect(
        parseOpensslVersion('OpenSSL 3.2.0 23 Nov 2023 (Library: OpenSSL 3.2.0)'),
        '3.2.0',
      );
    });

    test('parseOpensshVersion', () {
      expect(
        parseOpensshVersion('OpenSSH_9.6p1, OpenSSL 3.2.0 23 Nov 2023'),
        '9.6p1',
      );
    });

    test('parseGstreamerVersion', () {
      expect(
        parseGstreamerVersion(
          'gst-inspect-1.0 version 1.22.0\nGStreamer 1.22.0\n',
        ),
        '1.22.0',
      );
    });

    test('parseVersionPinFile', () {
      expect(parseVersionPinFile('3.41.9\n'), '3.41.9');
      expect(parseVersionPinFile('# comment\n2025.02.16\n'), '2025.02.16');
      expect(parseVersionPinFile(''), isNull);
    });
  });

  group('LinuxPlatformVersions soft-fail', () {
    test('missing tools yield null fields without throwing', () async {
      Future<ProcessResult> run(String exe, List<String> args) async {
        throw const ProcessException('missing', []);
      }

      Future<String?> readFile(String path) async => null;

      final snap = await LinuxPlatformVersions(
        runProcess: run,
        readFile: readFile,
        pathExists: (_) async => false,
      ).snapshot();

      expect(snap.operatingSystem, isNull);
      expect(snap.kernelRelease, isNull);
      expect(snap.selinuxMode, 'Disabled');
      expect(snap.busyboxVersion, isNull);
      expect(snap.glibcVersion, isNull);
      expect(snap.wpaSupplicantVersion, isNull);
      expect(snap.bluezVersion, isNull);
      expect(snap.opensslVersion, isNull);
      expect(snap.opensshVersion, isNull);
      expect(snap.gstreamerVersion, isNull);
      expect(snap.flutterVersion, isNull);
      expect(snap.buildrootVersion, isNull);
    });

    test('injected outputs populate fields independently', () async {
      final files = <String, String>{
        '/etc/os-release': '''
NAME="Cyber OS"
VERSION="1.0.0"
PRETTY_NAME="Cyber OS 1.0.0"
BUILDROOT_VERSION="2025.02.16"
''',
        '/sys/fs/selinux/enforce': '0\n',
        '/usr/share/flutter/flutter-engine.version': '3.41.9\n',
      };

      Future<ProcessResult> run(String exe, List<String> args) async {
        String text;
        switch (exe) {
          case 'uname':
            text = '6.1.118\n';
            break;
          case 'busybox':
            text = 'BusyBox v1.36.1 (built)\n';
            break;
          case 'ldd':
            text = 'ldd (GNU libc) 2.39\n';
            break;
          case 'wpa_supplicant':
            text = 'wpa_supplicant v2.10\n';
            break;
          case 'bluetoothd':
            text = '5.72\n';
            break;
          case 'openssl':
            text = 'OpenSSL 3.2.0 23 Nov 2023\n';
            break;
          case 'sshd':
            return ProcessResult(
              0,
              1,
              '',
              'OpenSSH_9.6p1, OpenSSL 3.2.0 23 Nov 2023\n',
            );
          case 'gst-inspect-1.0':
            text = 'GStreamer 1.22.0\n';
            break;
          case 'getenforce':
            text = 'Permissive\n';
            break;
          default:
            throw ProcessException(exe, args);
        }
        return ProcessResult(0, 0, text, '');
      }

      final snap = await LinuxPlatformVersions(
        runProcess: run,
        readFile: (p) async => files[p],
        pathExists: (p) async =>
            p == '/sys/fs/selinux' || files.containsKey(p),
      ).snapshot();

      expect(snap.operatingSystem, 'Cyber OS 1.0.0');
      expect(snap.osName, 'Cyber OS');
      expect(snap.osVersion, '1.0.0');
      expect(snap.kernelRelease, '6.1.118');
      expect(snap.selinuxMode, 'Permissive');
      expect(snap.busyboxVersion, '1.36.1');
      expect(snap.glibcVersion, '2.39');
      expect(snap.wpaSupplicantVersion, '2.10');
      expect(snap.bluezVersion, '5.72');
      expect(snap.opensslVersion, '3.2.0');
      expect(snap.opensshVersion, '9.6p1');
      expect(snap.gstreamerVersion, '1.22.0');
      expect(snap.flutterVersion, '3.41.9');
      expect(snap.buildrootVersion, '2025.02.16');
    });

    test('one failing probe does not clear others', () async {
      Future<ProcessResult> run(String exe, List<String> args) async {
        if (exe == 'busybox') {
          throw const ProcessException('busybox', []);
        }
        if (exe == 'uname') {
          return ProcessResult(0, 0, '6.1.0\n', '');
        }
        if (exe == 'openssl') {
          return ProcessResult(0, 0, 'OpenSSL 3.0.13 30 Jan 2024\n', '');
        }
        throw ProcessException(exe, args);
      }

      final snap = await LinuxPlatformVersions(
        runProcess: run,
        readFile: (_) async => null,
        pathExists: (_) async => false,
      ).snapshot();

      expect(snap.kernelRelease, '6.1.0');
      expect(snap.busyboxVersion, isNull);
      expect(snap.opensslVersion, '3.0.13');
    });
  });

  group('SecretsSealStatus', () {
    test('maps backend ids to UI labels', () {
      expect(
        SecretsSealStatus.fromBackendId(SecretsBackendId.softwareFallback),
        SecretsSealStatus.software,
      );
      expect(
        SecretsSealStatus.fromBackendId(SecretsBackendId.optee),
        SecretsSealStatus.opTee,
      );
      expect(
        SecretsSealStatus.fromBackendId(SecretsBackendId.fake),
        SecretsSealStatus.software,
      );
      expect(SecretsSealStatus.fromBackendId('op-tee'), 'op-tee');
    });

    test('fromProvider uses backendId only', () {
      expect(
        SecretsSealStatus.fromProvider(FakeKekProvider()),
        SecretsSealStatus.software,
      );
    });
  });
}
