import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_video/application/video_cover_extractor.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Extracts a JPEG frame at a media timestamp via rootfs GStreamer helper.
final class ProcessVideoAiFrameSampler {
  ProcessVideoAiFrameSampler({
    this.workdir,
    this.helperPath,
  });

  final String? workdir;
  final String? helperPath;

  Future<File?> extractJpegAt({
    required String videoPath,
    required String videoId,
    required int sampleMs,
  }) async {
    final src = File(videoPath);
    if (!await src.exists()) {
      return null;
    }
    final dir = Directory(
      workdir ?? '${OsPaths.varHmi}/ai-vision-frames/$videoId',
    );
    await dir.create(recursive: true);
    final out = File('${dir.path}/sample_${sampleMs.clamp(0, 1 << 30)}.jpg');

    if (VideoCoverExtractor.useFfmpegFallback) {
      return _extractWithFfmpeg(
        videoPath: videoPath,
        out: out,
        sampleMs: sampleMs,
      );
    }

    final bin = VideoCoverExtractor.resolveHelperPath(override: helperPath);
    try {
      final result = await Process.run(bin, [
        videoPath,
        out.path,
        '$sampleMs',
      ]).timeout(const Duration(seconds: 45));
      if (result.exitCode != 0 || !await out.exists() || await out.length() <= 0) {
        debugPrint(
          'process-video-ai: extract-video-frame failed ms=$sampleMs '
          'code=${result.exitCode} stderr=${result.stderr}',
        );
        return null;
      }
      return out;
    } catch (e) {
      debugPrint('process-video-ai: extract failed ms=$sampleMs: $e');
      return null;
    }
  }

  Future<File?> _extractWithFfmpeg({
    required String videoPath,
    required File out,
    required int sampleMs,
  }) async {
    final bundled = File(VideoCoverExtractor.bundledFfmpegPath);
    final bin =
        bundled.existsSync() ? VideoCoverExtractor.bundledFfmpegPath : 'ffmpeg';
    final ss = (sampleMs / 1000.0).toStringAsFixed(3);
    try {
      final result = await Process.run(bin, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-ss',
        ss,
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-q:v',
        '2',
        '-update',
        '1',
        out.path,
      ]).timeout(const Duration(seconds: 30));
      if (result.exitCode != 0 || !await out.exists() || await out.length() <= 0) {
        debugPrint(
          'process-video-ai: ffmpeg fallback failed ms=$sampleMs '
          'code=${result.exitCode}',
        );
        return null;
      }
      return out;
    } catch (e) {
      debugPrint('process-video-ai: ffmpeg fallback failed ms=$sampleMs: $e');
      return null;
    }
  }
}

/// Minimal JPEG SOF dimension probe (no image package).
final class JpegSize {
  const JpegSize(this.width, this.height);

  final int width;
  final int height;

  static JpegSize? fromFile(File file) {
    try {
      final raf = file.openSync(mode: FileMode.read);
      try {
        final header = raf.readSync(2);
        if (header.length < 2 || header[0] != 0xff || header[1] != 0xd8) {
          return null;
        }
        while (true) {
          final markerPrefix = raf.readSync(1);
          if (markerPrefix.isEmpty || markerPrefix[0] != 0xff) {
            return null;
          }
          int marker = 0;
          while (true) {
            final b = raf.readSync(1);
            if (b.isEmpty) {
              return null;
            }
            marker = b[0];
            if (marker != 0xff) {
              break;
            }
          }
          if (marker == 0xd9 || marker == 0xda) {
            return null;
          }
          final lenBytes = raf.readSync(2);
          if (lenBytes.length < 2) {
            return null;
          }
          final length = (lenBytes[0] << 8) | lenBytes[1];
          if (length < 2) {
            return null;
          }
          final payloadLen = length - 2;
          // SOF0..SOF3, SOF5..SOF7, SOF9..SOF11, SOF13..SOF15
          final isSof = (marker >= 0xc0 && marker <= 0xc3) ||
              (marker >= 0xc5 && marker <= 0xc7) ||
              (marker >= 0xc9 && marker <= 0xcb) ||
              (marker >= 0xcd && marker <= 0xcf);
          if (isSof) {
            final sof = raf.readSync(payloadLen);
            if (sof.length < 5) {
              return null;
            }
            final height = (sof[1] << 8) | sof[2];
            final width = (sof[3] << 8) | sof[4];
            if (width <= 0 || height <= 0) {
              return null;
            }
            return JpegSize(width, height);
          }
          raf.setPositionSync(raf.positionSync() + payloadLen);
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }

  static JpegSize? fromBytes(List<int> bytes) {
    final tmp = File(
      '${Directory.systemTemp.path}/jpeg_size_${identityHashCode(bytes)}.jpg',
    );
    try {
      tmp.writeAsBytesSync(bytes);
      return fromFile(tmp);
    } finally {
      try {
        tmp.deleteSync();
      } catch (_) {}
    }
  }
}
