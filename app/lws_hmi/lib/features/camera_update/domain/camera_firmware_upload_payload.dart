import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Resolves what bytes/filename to POST to camera CGI upgrade.
///
/// Vendor packages are often an outer `.zip` that contains a single
/// `upgrade.tar.gz`. The CGI expects that inner member (not the ZIP wrapper).
abstract final class CameraFirmwareUploadPayload {
  static const preferredMember = 'upgrade.tar.gz';

  /// ZIP local-file magic `PK\x03\x04`.
  static bool looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  /// Prefer inner [preferredMember] when [bytes] is a ZIP that contains it.
  static ({String fileName, Uint8List bytes}) resolve({
    required String sourceFileName,
    required Uint8List bytes,
  }) {
    if (!looksLikeZip(bytes)) {
      return (fileName: _safeUploadName(sourceFileName), bytes: bytes);
    }
    final extracted = extractZipMember(bytes, preferredMember);
    if (extracted != null && extracted.isNotEmpty) {
      debugPrint(
        'CameraFirmwareUploadPayload: extracted $preferredMember '
        '(${extracted.length} bytes) from $sourceFileName',
      );
      return (fileName: preferredMember, bytes: extracted);
    }
    debugPrint(
      'CameraFirmwareUploadPayload: no $preferredMember in ZIP; '
      'uploading outer $sourceFileName',
    );
    return (fileName: _safeUploadName(sourceFileName), bytes: bytes);
  }

  /// Basename without path; spaces kept (multipart filename is quoted).
  static String _safeUploadName(String sourceFileName) {
    final base = sourceFileName.split('/').last.split('\\').last;
    return base.isEmpty ? preferredMember : base;
  }

  /// Extracts one member from a simple ZIP (stored or deflate).
  ///
  /// Scans local file headers only (sufficient for vendor single-member pkgs).
  static Uint8List? extractZipMember(Uint8List data, String memberName) {
    var offset = 0;
    while (offset + 30 <= data.length) {
      if (data[offset] != 0x50 ||
          data[offset + 1] != 0x4b ||
          data[offset + 2] != 0x03 ||
          data[offset + 3] != 0x04) {
        break;
      }
      final compression = _u16(data, offset + 8);
      final compSize = _u32(data, offset + 18);
      final nameLen = _u16(data, offset + 26);
      final extraLen = _u16(data, offset + 28);
      final nameStart = offset + 30;
      final nameEnd = nameStart + nameLen;
      final dataStart = nameEnd + extraLen;
      final dataEnd = dataStart + compSize;
      if (nameEnd > data.length || dataEnd > data.length) {
        return null;
      }
      final name = utf8.decode(data.sublist(nameStart, nameEnd));
      final base = name.split('/').last;
      if (name == memberName || base == memberName) {
        final payload = data.sublist(dataStart, dataEnd);
        if (compression == 0) {
          return Uint8List.fromList(payload);
        }
        if (compression == 8) {
          try {
            final inflated =
                ZLibDecoder(raw: true).convert(payload);
            return Uint8List.fromList(inflated);
          } catch (e) {
            debugPrint(
              'CameraFirmwareUploadPayload: inflate $memberName failed: $e',
            );
            return null;
          }
        }
        debugPrint(
          'CameraFirmwareUploadPayload: unsupported compression=$compression',
        );
        return null;
      }
      offset = dataEnd;
    }
    return null;
  }

  static int _u16(Uint8List data, int offset) =>
      data[offset] | (data[offset + 1] << 8);

  static int _u32(Uint8List data, int offset) =>
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}
