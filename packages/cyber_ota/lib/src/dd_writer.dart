import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'ota_constants.dart';
import 'process_runner.dart';

typedef DdProgress = void Function(int bytesWritten, int bytesTotal);

/// Writes an image onto a block device (or file) with byte-accurate progress.
///
/// Progress matches host [`stream-file-progress.py`](scripts/stream-file-progress.py):
/// chunked read of the image, real `written/total` callbacks (about once per %).
///
/// **Block devices (`/dev/…`):** one long-lived **`dd of=<device> bs=… conv=fsync`**
/// reading image bytes from stdin (same pipe model as host stream → device `dd`).
/// Do **not** open `/dev` via Dart [RandomAccessFile] (eLinux may ENOENT), and do
/// **not** issue hundreds of skip/seek chunk `dd`s.
///
/// **Regular files** (unit tests / host): [RandomAccessFile] chunked copy.
final class DdWriter {
  DdWriter({
    ProcessRunner? processRunner,
    this.blockSize = kDdBlockSize,
  }) : _proc = processRunner ?? ProcessRunner();

  final ProcessRunner _proc;

  /// `dd` block size (`bs=`).
  final int blockSize;

  Future<void> writeImage({
    required String imagePath,
    required String devicePath,
    DdProgress? onProgress,
  }) async {
    final total = await File(imagePath).length();
    if (total <= 0) {
      throw StateError('empty image: $imagePath');
    }

    final target = await _resolveDevicePath(devicePath);
    if (target.startsWith('/dev/')) {
      await _writeBlockDeviceStream(
        imagePath: imagePath,
        devicePath: target,
        total: total,
        onProgress: onProgress,
      );
    } else {
      await _writeRegularFile(
        imagePath: imagePath,
        destPath: target,
        total: total,
        onProgress: onProgress,
      );
    }
  }

  /// Progress tick chunk sizing (host `stream-file-progress.py` formula).
  static int progressChunkSize(int total) {
    return math.min(1024 * 1024, math.max(1, total ~/ 200));
  }

  Future<void> _writeBlockDeviceStream({
    required String imagePath,
    required String devicePath,
    required int total,
    DdProgress? onProgress,
  }) async {
    // Do not use File.exists()/RandomAccessFile on /dev nodes: Flutter eLinux
    // dart:io may report ENOENT even when the node is present.
    final bs = math.max(512, blockSize - (blockSize % 512));
    // Prefer dd-aligned chunks for steady eMMC throughput; still report ~1%.
    final chunkSize = math.min(bs, math.max(progressChunkSize(total), 1));
    onProgress?.call(0, total);

    final process = await _proc.start(
      'dd',
      <String>[
        'of=$devicePath',
        'bs=$bs',
        'conv=fsync',
      ],
    );

    unawaited(process.stdout.drain<void>());
    final errChunks = StringBuffer();
    unawaited(
      process.stderr.transform(utf8.decoder).forEach(errChunks.write),
    );

    final src = await File(imagePath).open(mode: FileMode.read);
    var written = 0;
    var nextPercent = 0;
    Object? writeError;
    try {
      // addStream applies pipe backpressure (no per-chunk flush stutter).
      await process.stdin.addStream(
        _readChunks(
          src: src,
          chunkSize: chunkSize,
          total: total,
          onChunk: (n) {
            written += n;
            final percent = math.min(100, written * 100 ~/ total);
            if (onProgress != null &&
                (percent >= nextPercent || written >= total)) {
              onProgress(written, total);
              nextPercent = math.min(100, percent + 1);
            }
          },
        ),
      );
      await process.stdin.close();
    } catch (e) {
      writeError = e;
      try {
        await process.stdin.close();
      } catch (_) {}
      process.kill();
    } finally {
      await src.close();
    }

    final code = await process.exitCode;
    if (writeError != null) {
      throw StateError(
        'dd write $devicePath aborted after $written/$total: $writeError',
      );
    }
    if (code != 0) {
      final detail = errChunks.toString().trim();
      throw StateError(
        detail.isEmpty
            ? 'dd write $devicePath failed (exit $code)'
            : 'dd write $devicePath failed (exit $code): $detail',
      );
    }
    if (written != total) {
      throw StateError(
        'dd write $devicePath short (got $written want $total)',
      );
    }

    await _proc.run('sync', const <String>[]);
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

  Future<void> _writeRegularFile({
    required String imagePath,
    required String destPath,
    required int total,
    DdProgress? onProgress,
  }) async {
    final chunkSize = progressChunkSize(total);

    final src = await File(imagePath).open(mode: FileMode.read);
    final dst = await File(destPath).open(mode: FileMode.write);
    var written = 0;
    var nextPercent = 0;
    onProgress?.call(0, total);

    try {
      final buf = Uint8List(chunkSize);
      while (true) {
        final n = await src.readInto(buf);
        if (n <= 0) {
          break;
        }
        await dst.writeFrom(buf, 0, n);
        written += n;
        final percent = math.min(100, written * 100 ~/ total);
        if (percent >= nextPercent || written >= total) {
          onProgress?.call(written, total);
          nextPercent = math.min(100, percent + 1);
        }
      }
      await dst.flush();
    } finally {
      await src.close();
      await dst.close();
    }

    if (written != total) {
      throw StateError(
        'write $destPath short (got $written want $total)',
      );
    }
    await _proc.run('sync', const <String>[]);
    onProgress?.call(total, total);
  }

  static Future<String> _resolveDevicePath(String devicePath) async {
    try {
      final resolved = await File(devicePath).resolveSymbolicLinks();
      if (resolved.isNotEmpty) {
        return resolved;
      }
    } catch (_) {}
    try {
      final resolved = await Link(devicePath).resolveSymbolicLinks();
      if (resolved.isNotEmpty) {
        return resolved;
      }
    } catch (_) {}
    return devicePath;
  }
}
