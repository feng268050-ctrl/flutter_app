import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/peripheral_firmware_newest_wins.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/peripheral_firmware_manifest_url.dart';

void main() {
  group('PeripheralFirmwareNewestWins', () {
    test('prefers newer cloud over bundled', () {
      final selected = PeripheralFirmwareNewestWins.select(
        bundled: 1017,
        cloud: 1020,
        compare: PeripheralFirmwareNewestWins.compareControlBoardSw,
      );
      expect(selected, 1020);
    });

    test('prefers newer bundled over cloud', () {
      final selected = PeripheralFirmwareNewestWins.select(
        bundled: 1020,
        cloud: 1017,
        compare: PeripheralFirmwareNewestWins.compareControlBoardSw,
      );
      expect(selected, 1020);
    });

    test('equal versions prefer bundled', () {
      final selected = PeripheralFirmwareNewestWins.select(
        bundled: 'bundled',
        cloud: 'cloud',
        compare: (_, __) => 0,
      );
      expect(selected, 'bundled');
    });

    test('cloud soft-fail keeps bundled; alone marks cloudCheckFailed', () {
      // Soft-fail composition: select bundled when cloud leg is null.
      final withBundled = PeripheralFirmwareNewestWins.select<int>(
        bundled: 1017,
        cloud: null,
        compare: PeripheralFirmwareNewestWins.compareControlBoardSw,
      );
      expect(withBundled, 1017);
      expect(
        const PeripheralFirmwareOfferEvaluation<int>(
          offer: null,
          cloudCheckFailed: true,
        ).cloudCheckFailed,
        isTrue,
      );
      expect(
        const PeripheralFirmwareOfferEvaluation(
          offer: 1017,
          cloudCheckFailed: true,
        ).offer,
        1017,
      );
    });

    test('camera SemVer+build compare', () {
      expect(
        PeripheralFirmwareNewestWins.compareCameraKeys(
          (1, 0, 7, 20260513),
          (1, 0, 8, 20260101),
        ),
        lessThan(0),
      );
      expect(
        PeripheralFirmwareNewestWins.compareCameraKeys(
          (1, 0, 7, 20260514),
          (1, 0, 7, 20260513),
        ),
        greaterThan(0),
      );
    });
  });

  group('PeripheralFirmwareManifestUrl', () {
    test('uses CDN release.json paths', () {
      expect(
        PeripheralFirmwareManifestUrl.resolveControlBoard(),
        'https://cdn.lasercyber.com/lws-hmi/control-board/release.json',
      );
      expect(
        PeripheralFirmwareManifestUrl.resolveCamera(),
        'https://cdn.lasercyber.com/lws-hmi/camera/release.json',
      );
    });
  });
}
