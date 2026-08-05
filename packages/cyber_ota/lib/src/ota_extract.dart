import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dd_writer.dart';
import 'process_runner.dart';

typedef ExtractProgress = void Function(int bytesRead, int bytesTotal);

/// Extracts `ota-package.tar.gz` into the staging directory via `tar`.
///
/// Feeds the archive to **`tar -xz`** on stdin in chunks (same progress model as
/// [`stream-file-progress.py`](scripts/stream-file-progress.py) / [DdWriter]):
/// percent advances with compressed archive bytes consumed.
class OtaExtract {
  OtaExtract({ProcessRunner? processRunner})
      : _proc = processRunner ?? ProcessRunner();

  final ProcessRunner _proc;

  Future<void> extractArchive({
    required String archivePath,
    required String stagingDir,
    ExtractProgress? onProgress,
  }) async {
    final dir = stagingDir.endsWith('/')
        ? stagingDir.substring(0, stagingDir.length - 1)
        : stagingDir;
    final total = await File(archivePath).length();
    if (total <= 0) {
      throw StateError('empty archive: $archivePath');
    }

    final chunkSize = DdWriter.progressChunkSize(total);
    onProgress?.call(0, total);

    final process = await _proc.start(
      'tar',
      <String>['-C', dir, '-xz'],
    );

    unawaited(process.stdout.drain<void>());
    final errChunks = StringBuffer();
    unawaited(
      process.stderr.transform(utf8.decoder).forEach(errChunks.write),
    );

    final src = await File(archivePath).open(mode: FileMode.read);
    var read = 0;
    var nextPercent = 0;
    Object? feedError;
    try {
      await process.stdin.addStream(
        _readChunks(
          src: src,
          chunkSize: chunkSize,
          total: total,
          onChunk: (n) {
            read += n;
            final percent = math.min(100, read * 100 ~/ total);
            if (onProgress != null &&
                (percent >= nextPercent || read >= total)) {
              onProgress(read, total);
              nextPercent = math.min(100, percent + 1);
            }
          },
        ),
      );
      await process.stdin.close();
    } catch (e) {
      feedError = e;
      try {
        await process.stdin.close();
      } catch (_) {}
      process.kill();
    } finally {
      await src.close();
    }

    final code = await process.exitCode;
    if (feedError != null) {
      throw StateError(
        'tar extract aborted after $read/$total: $feedError',
      );
    }
    if (code != 0) {
      final detail = errChunks.toString().trim();
      throw StateError(
        detail.isEmpty
            ? 'tar extract failed (exit $code)'
            : 'tar extract failed (exit $code): $detail',
      );
    }
    if (read != total) {
      throw StateError('tar extract short feed (got $read want $total)');
    }
    onProgress?.call(total, total);
  }

  static Stream<List<int>> _readChunks({
    required RandomAccessFile src,
    required int chunkSize,
    required int total,
    required void Function(int n) onChunk,
  }) async* {
    final buf = Uint8List(chunkSize);
    var remaining = total;
    while (remaining > 0) {
      final want = math.min(chunkSize, remaining);
      final n = await src.readInto(buf, 0, want);
      if (n <= 0) {
        break;
      }
      final chunk = Uint8List(n)..setRange(0, n, buf);
      yield chunk;
      onChunk(n);
      remaining -= n;
    }
  }
}
