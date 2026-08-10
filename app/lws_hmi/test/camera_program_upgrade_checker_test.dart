import 'dart:io';

import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_checker.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';
import 'package:lws_hmi/features/camera_update/domain/camera_firmware_upload_payload.dart';
import 'package:lws_hmi/features/camera_update/infrastructure/bundled_camera_firmware_assets.dart';

void main() {
  group('BundledCameraFirmwareVersionGate', () {
    test('parses filename SemVer+build+model', () {
      const name = 'LTC609-v1.0.7 build20260513.zip';
      expect(
        BundledCameraFirmwareVersionGate.isValidFirmwareFileName(name),
        isTrue,
      );
      final v = BundledCameraFirmwareVersionGate.parseFileName(name)!;
      expect(v.model, 'LTC609');
      expect(v.displaySemVer, '1.0.7');
      expect(v.build, 20260513);
    });

    test('parses device appVersion with build', () {
      final v = BundledCameraFirmwareVersionGate.parseAppVersion(
        'v1.0.5 build20251127',
      )!;
      expect(v.displaySemVer, '1.0.5');
      expect(v.build, 20251127);
    });

    test('rejects invalid names', () {
      expect(
        BundledCameraFirmwareVersionGate.isValidFirmwareFileName(
          'firmware.zip',
        ),
        isFalse,
      );
      expect(
        BundledCameraFirmwareVersionGate.parseAppVersion('not-a-version'),
        isNull,
      );
    });

    test('offers upgrade only when bundled strictly greater', () {
      const name = 'LTC609-v1.0.7 build20260513.zip';
      expect(
        BundledCameraFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceAppVersionRaw: 'v1.0.5 build20251127',
        ),
        isTrue,
      );
      expect(
        BundledCameraFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceAppVersionRaw: 'v1.0.7 build20260513',
        ),
        isFalse,
      );
      expect(
        BundledCameraFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceAppVersionRaw: 'v1.0.7 build20260514',
        ),
        isFalse,
      );
      expect(
        BundledCameraFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceAppVersionRaw: 'v1.0.8 build20250101',
        ),
        isFalse,
      );
    });
  });

  group('BundledCameraFirmwareAssets.selectLatestFileName', () {
    test('picks highest SemVer then build for model', () {
      final selected = BundledCameraFirmwareAssets.selectLatestFileName(
        const [
          'LTC609-v1.0.5 build20251127.zip',
          'LTC609-v1.0.7 build20260513.zip',
          'LTC609-v1.0.7 build20260101.zip',
          'OTHER-v9.9.9 build20990101.zip',
        ],
        model: 'ltc609',
      );
      expect(selected, 'LTC609-v1.0.7 build20260513.zip');
    });

    test('picks overall newest when model omitted', () {
      final selected = BundledCameraFirmwareAssets.selectLatestFileName(
        const [
          'LTC609-v1.0.7 build20260513.zip',
          'OTHER-v2.0.0 build20200101.zip',
        ],
      );
      expect(selected, 'OTHER-v2.0.0 build20200101.zip');
    });
  });

  group('CameraProgramUpgradeChecker', () {
    test('finds newer bundled ZIP', () async {
      final checker = CameraProgramUpgradeChecker(
        deviceAppVersionRaw: 'v1.0.5 build20251127',
        assetFileNames: const [
          'LTC609-v1.0.7 build20260513.zip',
        ],
      );
      final result = await checker.check(currentVersion: '1.0.5');
      expect(result, isA<UpgradeCheckAvailable>());
      final offer = (result as UpgradeCheckAvailable).offer;
      expect(offer.channel, UpgradeChannel.cameraProgram);
      expect(offer.version, 'v1.0.7 build20260513');
    });

    test('same version is up to date', () async {
      final checker = CameraProgramUpgradeChecker(
        deviceAppVersionRaw: 'v1.0.7 build20260513',
        assetFileNames: const [
          'LTC609-v1.0.7 build20260513.zip',
        ],
      );
      final result = await checker.check(currentVersion: '1.0.7');
      expect(result, isA<UpgradeCheckUpToDate>());
    });

    test('unreachable camera is unavailable', () async {
      final checker = CameraProgramUpgradeChecker(
        deviceAppVersionRaw: null,
        assetFileNames: const [
          'LTC609-v1.0.7 build20260513.zip',
        ],
      );
      final result = await checker.check(currentVersion: '');
      expect(result, isA<UpgradeCheckUnavailable>());
    });

    test('host force policy skips version gate in checker', () async {
      final checker = CameraProgramUpgradeChecker(
        deviceAppVersionRaw: 'v1.0.5 build20251127',
        assetFileNames: const [
          'LTC609-v1.0.7 build20260513.zip',
        ],
      );
      final result = await checker.check(
        currentVersion: '1.0.5',
        policy: UpgradePolicy.hostForce,
      );
      expect(result, isA<UpgradeCheckUnavailable>());
    });
  });

  group('CameraFirmwareUploadPayload', () {
    test('extracts upgrade.tar.gz from vendor ZIP', () {
      final zipPath = File(
        '${Directory.current.path}/assets/firmware/camera/'
        'LTC609-v1.0.7 build20260513.zip',
      );
      // Tests may run with cwd=app/lws_hmi or repo root.
      final candidates = [
        zipPath,
        File(
          '${Directory.current.path}/app/lws_hmi/assets/firmware/camera/'
          'LTC609-v1.0.7 build20260513.zip',
        ),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => zipPath,
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      final zipBytes = file.readAsBytesSync();
      expect(CameraFirmwareUploadPayload.looksLikeZip(zipBytes), isTrue);
      final payload = CameraFirmwareUploadPayload.resolve(
        sourceFileName: file.uri.pathSegments.last,
        bytes: Uint8List.fromList(zipBytes),
      );
      expect(payload.fileName, 'upgrade.tar.gz');
      expect(payload.bytes.length, greaterThan(1000000));
      // gzip magic
      expect(payload.bytes[0], 0x1f);
      expect(payload.bytes[1], 0x8b);
    });

    test('non-zip bytes pass through', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final payload = CameraFirmwareUploadPayload.resolve(
        sourceFileName: 'raw.bin',
        bytes: bytes,
      );
      expect(payload.fileName, 'raw.bin');
      expect(payload.bytes, bytes);
    });
  });
}
