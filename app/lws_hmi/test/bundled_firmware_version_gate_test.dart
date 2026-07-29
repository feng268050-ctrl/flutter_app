import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/firmware_upgrade_constants.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/bundled_firmware_assets.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/upgrade_packet_builder.dart';

void main() {
  group('BundledFirmwareVersionGate', () {
    test('parses HW/SW from LSW01 filename', () {
      const name = 'LSW01H1000S1017.bin';
      expect(BundledFirmwareVersionGate.isValidFirmwareFileName(name), isTrue);
      expect(BundledFirmwareVersionGate.hardwareVersion(name), 1000);
      expect(BundledFirmwareVersionGate.softwareVersion(name), 1017);
    });

    test('rejects invalid names', () {
      expect(
        BundledFirmwareVersionGate.isValidFirmwareFileName('firmware.bin'),
        isFalse,
      );
      expect(
        BundledFirmwareVersionGate.isValidFirmwareFileName('LSW01H100S1017.bin'),
        isFalse,
      );
    });

    test('offers upgrade only when HW matches and SW strictly greater', () {
      const name = 'LSW01H1000S1013.bin';
      expect(
        BundledFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceHw: 1000,
          deviceSw: 1012,
        ),
        isTrue,
      );
      expect(
        BundledFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceHw: 1000,
          deviceSw: 1013,
        ),
        isFalse,
      );
      expect(
        BundledFirmwareVersionGate.isUpgradeCandidate(
          bundledFileName: name,
          deviceHw: 1001,
          deviceSw: 1012,
        ),
        isFalse,
      );
    });
  });

  group('BundledFirmwareAssets.selectLatestFileName', () {
    test('picks highest SW for matching HW', () {
      final selected = BundledFirmwareAssets.selectLatestFileName(
        const [
          'LSW01H1000S1013.bin',
          'LSW01H1000S1017.bin',
          'LSW01H1000S1015.bin',
          'LSW01H1001S1099.bin',
        ],
        deviceHw: 1000,
      );
      expect(selected, 'LSW01H1000S1017.bin');
    });

    test('picks overall highest SW when deviceHw omitted', () {
      final selected = BundledFirmwareAssets.selectLatestFileName(
        const [
          'LSW01H1000S1017.bin',
          'LSW01H1001S1099.bin',
        ],
      );
      expect(selected, 'LSW01H1001S1099.bin');
    });

    test('returns null when no HW match', () {
      expect(
        BundledFirmwareAssets.selectLatestFileName(
          const ['LSW01H1000S1017.bin'],
          deviceHw: 1001,
        ),
        isNull,
      );
    });
  });

  group('UpgradePacketBuilder frames (lws-ui lengths)', () {
    test('info frame is 10 words', () {
      final frame = UpgradePacketBuilder.infoFrame(
        hw: 1000,
        sw: 1017,
        fileLength: 65364,
        checkCode: 42,
      );
      expect(frame.address, 0);
      expect(frame.words.length, 10);
      expect(frame.words[0], 1000);
      expect(frame.words[1], 1017);
      expect(frame.words[9], FirmwareUpgradeConstants.firmwareInfo);
    });

    test('data frame is header+crc+reserved+payload (not padded to 64)', () {
      final chunk = Uint8List.fromList([0x11, 0x22, 0x33]);
      final frame = UpgradePacketBuilder.dataFrame(
        hw: 1000,
        sw: 1017,
        fileLength: 100,
        checkCode: 1,
        offset: 0,
        chunk: chunk,
      );
      // 6 base + 4 offset/cmd + 2 crc + 4 reserved + 2 payload words
      expect(frame.words.length, 18);
      expect(frame.words[8], 3); // byte count
      expect(frame.words[9], FirmwareUpgradeConstants.firmwareData);
      expect(frame.words[16], 0x2211);
      expect(frame.words[17], 0x0033);
    });

    test('end frame is 14 words', () {
      final frame = UpgradePacketBuilder.endFrame(hw: 1000, sw: 1017);
      expect(frame.words.length, 14);
      expect(frame.words[9], FirmwareUpgradeConstants.firmwareEnd);
    });

    test('splits high/low 16-bit halves', () {
      expect(UpgradePacketBuilder.splitHighLow(0x12345678), [0x1234, 0x5678]);
      expect(UpgradePacketBuilder.splitHighLow(65364), [0, 65364]);
    });

    test('file check code sums unsigned bytes', () {
      final bytes = Uint8List.fromList([1, 2, 255]);
      expect(UpgradePacketBuilder.fileCheckCode(bytes), 1 + 2 + 255);
    });
  });
}
