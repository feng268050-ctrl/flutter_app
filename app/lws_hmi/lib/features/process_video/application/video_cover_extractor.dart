import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Extracts a JPEG cover frame from a local MP4 (lws-ui `VideoCoverExtractor`).
///
/// Prefers App-bundled `/opt/hmi/bin/ffmpeg` (board rootfs has no ffmpeg).
final class VideoCoverExtractor {
  VideoCoverExtractor({
    this.coversDir,
    this.ffmpegPath,
  });

  final String? coversDir;

  /// Override for tests; production resolves via [resolveFfmpegPath].
  final String? ffmpegPath;

  static const bundledFfmpegPath = '/opt/hmi/bin/ffmpeg';

  /// Prefer App companion binary, then PATH `ffmpeg`.
  static String resolveFfmpegPath({String? override}) {
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final bundled = File(bundledFfmpegPath);
    if (bundled.existsSync()) {
      return bundledFfmpegPath;
    }
    return 'ffmpeg';
  }

  Future<File?> extractFirstFrameJpeg({
    required String videoPath,
    required String videoId,
  }) async {
    final src = File(videoPath);
    if (!await src.exists()) {
      return null;
    }
    final dir = Directory(coversDir ?? '${OsPaths.varHmi}/video-covers');
    await dir.create(recursive: true);
    final out = File('${dir.path}/$videoId.jpg');
    final bin = resolveFfmpegPath(override: ffmpegPath);
    try {
      final result = await Process.run(bin, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-ss',
        '0',
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-q:v',
        '2',
        '-update',
        '1',
        out.path,
      ]).timeout(const Duration(seconds: 45));
      if (result.exitCode != 0 || !await out.exists() || await out.length() <= 0) {
        debugPrint(
          'video-cover: ffmpeg failed bin=$bin code=${result.exitCode} '
          'stderr=${result.stderr}',
        );
        return null;
      }
      return out;
    } catch (e) {
      debugPrint('video-cover: extract failed bin=$bin: $e');
    }
    return null;
  }
}
