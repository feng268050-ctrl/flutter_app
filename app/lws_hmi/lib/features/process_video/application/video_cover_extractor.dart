import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Extracts a JPEG cover frame from a local MP4 (lws-ui `VideoCoverExtractor`).
///
/// Uses rootfs GStreamer helper [/usr/libexec/hmi/extract-video-frame].
final class VideoCoverExtractor {
  VideoCoverExtractor({
    this.coversDir,
    this.helperPath,
  });

  final String? coversDir;

  /// Override for tests; production resolves via [resolveHelperPath].
  final String? helperPath;

  static const bundledHelperPath = '/usr/libexec/hmi/extract-video-frame';

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
}
