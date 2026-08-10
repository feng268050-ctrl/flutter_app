import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/peripheral_firmware_newest_wins.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';
import 'package:lws_hmi/features/camera_update/domain/camera_cloud_manifest.dart';

void main() {
  group('CameraCloudManifest', () {
    const name = 'LTC609-v1.0.7 build20260513.zip';
    const url =
        'https://cdn.example/lws-hmi/camera/LTC609-v1.0.7%20build20260513.zip';
    final expected = BundledCameraFirmwareVersionGate.parseFileName(name)!;

    test('offers when filename SemVer+build newer than device', () {
      final c = CameraCloudManifest.tryParseOffer(
        json: {
          'version': 'v1.0.7',
          'filename': name,
          'url': url,
        },
        deviceAppVersionRaw: 'v1.0.5 build20251127',
      );
      expect(c, isNotNull);
      expect(c!.version.displaySemVer, '1.0.7');
      expect(c.version.build, 20260513);
      expect(c.version.label, 'v1.0.7 build20260513');
    });

    test('channel version matches SemVer-only publish shape', () {
      expect(
        CameraCloudManifest.channelVersionMatches('v1.0.7', expected),
        isTrue,
      );
      expect(
        CameraCloudManifest.channelVersionMatches('1.0.7', expected),
        isTrue,
      );
      // Legacy full label / Maven-style still match on SemVer.
      expect(
        CameraCloudManifest.channelVersionMatches(
          'v1.0.7 build20260513',
          expected,
        ),
        isTrue,
      );
      expect(
        CameraCloudManifest.channelVersionMatches('v1.0.7+20260513', expected),
        isTrue,
      );
      expect(
        CameraCloudManifest.channelVersionMatches('v1.0.8', expected),
        isFalse,
      );
    });

    test('rejects same or older', () {
      expect(
        CameraCloudManifest.tryParseOffer(
          json: {
            'version': 'v1.0.7',
            'filename': name,
            'url': url,
          },
          deviceAppVersionRaw: 'v1.0.7 build20260513',
        ),
        isNull,
      );
      expect(
        CameraCloudManifest.tryParseOffer(
          json: {
            'version': 'v1.0.7',
            'filename': name,
            'url': url,
          },
          deviceAppVersionRaw: 'v1.0.8 build20260101',
        ),
        isNull,
      );
    });

    test('falls back to URL-decoded basename', () {
      final c = CameraCloudManifest.tryParseOffer(
        json: {'version': 'v1.0.7', 'url': url},
        deviceAppVersionRaw: 'v1.0.5 build20251127',
      );
      expect(c, isNotNull);
      expect(c!.fileName, name);
    });

    test('still gates on filename when channel version is wrong', () {
      final c = CameraCloudManifest.tryParseOffer(
        json: {
          'version': 'v9.9.9',
          'filename': name,
          'url': url,
        },
        deviceAppVersionRaw: 'v1.0.5 build20251127',
      );
      expect(c, isNotNull);
      expect(c!.version.label, 'v1.0.7 build20260513');
      expect(
        CameraCloudManifest.channelVersionMatches('v9.9.9', c.version),
        isFalse,
      );
    });

    test('newest-wins prefers higher SemVer then build; tie prefers bundled', () {
      expect(
        PeripheralFirmwareNewestWins.compareCameraKeys(
          (1, 0, 7, 20260513),
          (1, 0, 8, 20260101),
        ),
        lessThan(0),
      );
      expect(
        PeripheralFirmwareNewestWins.select(
          bundled: 'bundled',
          cloud: 'cloud',
          compare: (_, __) => 0,
        ),
        'bundled',
      );
    });
  });
}
