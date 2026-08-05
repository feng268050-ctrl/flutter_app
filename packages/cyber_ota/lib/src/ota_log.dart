import 'dart:io';

import 'ota_constants.dart';
import 'ota_progress.dart';

/// Append-only OTA debug log under the staging directory (`ota.log`).
final class OtaLog {
  OtaLog(this.stagingDir);

  final String stagingDir;

  String get _dirPath {
    if (stagingDir.endsWith('/')) {
      return stagingDir.substring(0, stagingDir.length - 1);
    }
    return stagingDir;
  }

  String get path => '$_dirPath/$kOtaLogFileName';

  Future<void> clear() async {
    try {
      final dir = Directory(_dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await File(path).writeAsString('', flush: true);
    } catch (_) {}
  }

  Future<void> line(String message) async {
    try {
      final dir = Directory(_dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ts = DateTime.now().toUtc().toIso8601String();
      await File(path).writeAsString(
        '$ts $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Best-effort debug log only.
    }
  }

  Future<void> progress(OtaProgress progress) {
    final buf = StringBuffer()
      ..write('phase=${progress.phase.wireName}')
      ..write(' percent=${progress.percent}');
    if (progress.bytesTotal > 0) {
      buf.write(' bytes=${progress.bytesReceived}/${progress.bytesTotal}');
    }
    if (progress.ingress != null) {
      buf.write(' ingress=${progress.ingress!.wireName}');
    }
    if (progress.message.isNotEmpty) {
      buf.write(' msg=${progress.message}');
    }
    if (progress.errorCode.isNotEmpty) {
      buf.write(' err=${progress.errorCode}');
    }
    return line(buf.toString());
  }
}
