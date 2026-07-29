import 'dart:typed_data';

import 'package:lws_hmi/features/bundled_firmware/domain/firmware_upgrade_constants.dart';

/// Builds contiguous holding-register frames matching lws-ui ModbusFiledBuilder.
///
/// Frames start at holding address `0x0000` and are written with FC16 for
/// exactly [UpgradeFrame.words.length] registers (not the full 80-word group).
abstract final class UpgradePacketBuilder {
  static const upgradeHoldingStart = 0x0000;

  /// Reserved holding words `0x000C`–`0x000F` (lws-ui createUpgradeEmptyFiled).
  static const reservedWordCount = 4;

  static List<int> splitHighLow(int value) {
    final v = value & 0xFFFFFFFF;
    return [(v >> 16) & 0xFFFF, v & 0xFFFF];
  }

  /// Sum of unsigned bytes (file check code).
  static int fileCheckCode(Uint8List bytes) {
    var sum = 0;
    for (final b in bytes) {
      sum += b & 0xFF;
    }
    return sum;
  }

  /// Packet CRC = sum of high+low bytes for each word in the payload.
  static int packetCheckCode(Uint8List chunk) {
    var check = 0;
    final dataSize =
        ((chunk.length % 2 == 0 ? chunk.length : chunk.length + 1) / 2).floor();
    for (var j = 0; j < dataSize; j++) {
      final highIndex = 2 * j;
      final lowIndex = highIndex + 1;
      final high = chunk[highIndex] & 0xFF;
      final low = lowIndex < chunk.length ? (chunk[lowIndex] & 0xFF) : 0;
      check += high + low;
    }
    return check;
  }

  /// Word layout matches lws-ui: `(lowByte << 8) | highByte` per pair.
  /// Only [dataSize] words — not padded to 64 (last packet is shorter).
  static List<int> packDataWords(Uint8List chunk) {
    final dataSize =
        ((chunk.length % 2 == 0 ? chunk.length : chunk.length + 1) / 2).floor();
    final words = <int>[];
    for (var j = 0; j < dataSize; j++) {
      final highIndex = 2 * j;
      final lowIndex = highIndex + 1;
      final high = chunk[highIndex] & 0xFF;
      final low = lowIndex < chunk.length ? (chunk[lowIndex] & 0xFF) : 0;
      words.add(((low << 8) | high) & 0xFFFF);
    }
    return words;
  }

  static List<int> _baseInfoWords({
    required int hw,
    required int sw,
    required int fileLength,
    required int checkCode,
  }) {
    final size = splitHighLow(fileLength);
    final check = splitHighLow(checkCode);
    return [
      hw & 0xFFFF,
      sw & 0xFFFF,
      size[0],
      size[1],
      check[0],
      check[1],
    ];
  }

  /// lws-ui `createControllerUpgradeFileInfoData` — 10 words @ 0x0000.
  static UpgradeFrame infoFrame({
    required int hw,
    required int sw,
    required int fileLength,
    required int checkCode,
  }) {
    return UpgradeFrame(
      address: upgradeHoldingStart,
      words: [
        ..._baseInfoWords(
          hw: hw,
          sw: sw,
          fileLength: fileLength,
          checkCode: checkCode,
        ),
        0, // offset high
        0, // offset low
        0, // byte count
        FirmwareUpgradeConstants.firmwareInfo,
      ],
    );
  }

  /// lws-ui `createControllerUpgradeFilePackageDataAtOffset` —
  /// base + offset/cmd + CRC + reserved + payload words only.
  static UpgradeFrame dataFrame({
    required int hw,
    required int sw,
    required int fileLength,
    required int checkCode,
    required int offset,
    required Uint8List chunk,
  }) {
    final off = splitHighLow(offset);
    final crc = splitHighLow(packetCheckCode(chunk));
    final payload = packDataWords(chunk);
    return UpgradeFrame(
      address: upgradeHoldingStart,
      words: [
        ..._baseInfoWords(
          hw: hw,
          sw: sw,
          fileLength: fileLength,
          checkCode: checkCode,
        ),
        off[0],
        off[1],
        chunk.length & 0xFFFF,
        FirmwareUpgradeConstants.firmwareData,
        crc[0],
        crc[1],
        ...List<int>.filled(reservedWordCount, 0),
        ...payload,
      ],
    );
  }

  /// lws-ui `createUpgradeEndFromFileVersions` — 10 cmd words + 4 reserved.
  static UpgradeFrame endFrame({
    required int hw,
    required int sw,
  }) {
    return UpgradeFrame(
      address: upgradeHoldingStart,
      words: [
        hw & 0xFFFF,
        sw & 0xFFFF,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        FirmwareUpgradeConstants.firmwareEnd,
        ...List<int>.filled(reservedWordCount, 0),
      ],
    );
  }
}

/// One FC16 OTA frame (start address + contiguous words).
final class UpgradeFrame {
  const UpgradeFrame({required this.address, required this.words});

  final int address;
  final List<int> words;
}
