import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/control_board_cloud_manifest.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/peripheral_firmware_newest_wins.dart';

void main() {
  group('ControlBoardCloudManifest', () {
    const url = 'https://cdn.example/lws-hmi/control-board/LSW01H1000S1017.bin';

    test('offers when filename SW newer and HW matches', () {
      final c = ControlBoardCloudManifest.tryParseOffer(
        json: {
          'version': '1017',
          'filename': 'LSW01H1000S1017.bin',
          'url': url,
          'title': 'Control board 1017',
          'content': 'Fixes Modbus timeouts.',
        },
        deviceHw: 1000,
        deviceSw: 1010,
      );
      expect(c, isNotNull);
      expect(c!.softwareVersion, 1017);
      expect(c.hardwareVersion, 1000);
      expect(c.fileName, 'LSW01H1000S1017.bin');
      expect(c.title, 'Control board 1017');
      expect(c.content, 'Fixes Modbus timeouts.');
    });

    test('ignores wrong channel version string; filename SW wins', () {
      // Legacy mistaken publish: version was vLSW01H1000S1017
      final c = ControlBoardCloudManifest.tryParseOffer(
        json: {
          'version': 'vLSW01H1000S1017',
          'filename': 'LSW01H1000S1017.bin',
          'url': url,
        },
        deviceHw: 1000,
        deviceSw: 1010,
      );
      expect(c, isNotNull);
      expect(c!.softwareVersion, 1017);
      expect(
        ControlBoardCloudManifest.channelVersionMatchesSw(
          'vLSW01H1000S1017',
          1017,
        ),
        isFalse,
      );
      expect(
        ControlBoardCloudManifest.channelVersionMatchesSw('1017', 1017),
        isTrue,
      );
      // Legacy v-prefix still accepted as matching metadata.
      expect(
        ControlBoardCloudManifest.channelVersionMatchesSw('v1017', 1017),
        isTrue,
      );
    });

    test('rejects same or older SW', () {
      expect(
        ControlBoardCloudManifest.tryParseOffer(
          json: {
            'version': '1017',
            'filename': 'LSW01H1000S1017.bin',
            'url': url,
          },
          deviceHw: 1000,
          deviceSw: 1017,
        ),
        isNull,
      );
      expect(
        ControlBoardCloudManifest.tryParseOffer(
          json: {
            'version': '1017',
            'filename': 'LSW01H1000S1017.bin',
            'url': url,
          },
          deviceHw: 1000,
          deviceSw: 1020,
        ),
        isNull,
      );
    });

    test('rejects HW mismatch', () {
      expect(
        ControlBoardCloudManifest.tryParseOffer(
          json: {
            'version': '1017',
            'filename': 'LSW01H1000S1017.bin',
            'url': url,
          },
          deviceHw: 1001,
          deviceSw: 1010,
        ),
        isNull,
      );
    });

    test('falls back to URL basename when filename missing', () {
      final c = ControlBoardCloudManifest.tryParseOffer(
        json: {'version': '1017', 'url': url},
        deviceHw: 1000,
        deviceSw: 1010,
      );
      expect(c, isNotNull);
      expect(c!.fileName, 'LSW01H1000S1017.bin');
    });

    test('newest-wins prefers higher SW; tie prefers bundled', () {
      expect(
        PeripheralFirmwareNewestWins.select(
          bundled: 1017,
          cloud: 1020,
          compare: PeripheralFirmwareNewestWins.compareControlBoardSw,
        ),
        1020,
      );
      expect(
        PeripheralFirmwareNewestWins.select(
          bundled: 'bundled-1020',
          cloud: 'cloud-1020',
          compare: (_, __) => 0,
        ),
        'bundled-1020',
      );
    });
  });
}
