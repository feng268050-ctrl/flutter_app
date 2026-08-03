import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Extracts a JPEG cover frame from a local MP4 (lws-ui `VideoCoverExtractor`).
///
/// Uses rootfs GStreamer helper [/usr/libexec/hmi/extract-video-frame]
/// (not App-bundled ffmpeg).
final class VideoCoverExtractor {
  VideoCoverExtractor({
    this.coversDir,
    this.helperPath,
  });

  final String? coversDir;

  /// Override for tests; production resolves via [resolveHelperPath].
  final String? helperPath;

  static const bundledHelperPath = '/usr/libexec/hmi/extract-video-frame';

  /// Optional legacy ffmpeg path (only when [useFfmpegFallback] is true).
  static const bundledFfmpegPath = '/opt/hmi/bin/ffmpeg';

  /// Transition flag: set `LWS_HMI_COVER_FFMPEG=1` to use bundled ffmpeg.
  /// Default off — product path is GStreamer.
  static bool get useFfmpegFallback =>
      Platform.environment['LWS_HMI_COVER_FFMPEG'] == '1';

  static String resolveHelperPath({String? override}) {
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return bundledHelperPath;
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
    // Reuse cache — avoid spawning MPP JPEG encode on every detail open
    // (concurrent with video_player MPP decode has caused HMI SIGSEGV).
    if (await out.exists() && await out.length() > 0) {
      return out;
    }

    if (useFfmpegFallback) {
      return _extractWithFfmpeg(videoPath: videoPath, out: out);
    }

    final bin = resolveHelperPath(override: helperPath);
    try {
      final result = await Process.run(bin, [
        videoPath,
        out.path,
      ]).timeout(const Duration(seconds: 45));
      if (result.exitCode != 0 || !await out.exists() || await out.length() <= 0) {
        debugPrint(
          'video-cover: extract-video-frame failed bin=$bin '
          'code=${result.exitCode} stderr=${result.stderr}',
        );
        return null;
      }
      return out;
    } catch (e) {
      debugPrint('video-cover: extract failed bin=$bin: $e');
    }
    return null;
  }

  Future<File?> _extractWithFfmpeg({
    required String videoPath,
    required File out,
  }) async {
    final bundled = File(bundledFfmpegPath);
    final bin = bundled.existsSync() ? bundledFfmpegPath : 'ffmpeg';
    try {
      final result = await Process.run(bin, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        videoPath,
        '-an',
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
          'video-cover: ffmpeg fallback failed bin=$bin code=${result.exitCode}',
        );
        return null;
      }
      return out;
    } catch (e) {
      debugPrint('video-cover: ffmpeg fallback failed: $e');
      return null;
    }
  }
}
