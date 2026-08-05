import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Bundled Home backdrop / hero / quick-action assets (from lws-ui, WebP).
abstract final class HomeAssets {
  static const backdrop = 'assets/home/home_back.webp';
  static const leftAnimated = 'assets/home/home_left_1m.webp';
  static const rightAnimated = 'assets/home/home_right_1m.webp';
  static const leftStatic = 'assets/home/home_left_img.webp';
  static const rightStatic = 'assets/home/home_right_img.webp';
  static const quickMode = 'assets/home/home_fast.webp';
  static const engineerMode = 'assets/home/home_engine.webp';
  static const quickModeTextEn = 'assets/home/home_fast_text_en.webp';
  static const engineerModeTextEn = 'assets/home/home_engine_text_en.webp';
  static const settingsIcon = 'assets/home/home_settings.webp';
  static const monitorIcon = 'assets/home/home_monitor.webp';
  static const aiVisionIcon = 'assets/home/ai_vision_home.webp';

  /// Decode size for [backdrop], matching [_HomeBackdrop] `cacheWidth`/`Height`.
  static (int width, int height) backdropCachePx({
    required Size logicalSize,
    required double devicePixelRatio,
  }) {
    final w = (logicalSize.width * devicePixelRatio).round().clamp(640, 1920);
    final h = (logicalSize.height * devicePixelRatio).round().clamp(400, 1200);
    return (w, h);
  }

  /// Warm the image cache before Home paints so wallpaper is not last.
  ///
  /// Uses the same [ResizeImage] dimensions as [Image.asset] cache* so the
  /// first Home frame hits cache. Safe to call before [runApp] (no BuildContext).
  static Future<void> precacheBackdrop() async {
    final views = SchedulerBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return;
    }
    final view = views.first;
    final dpr = view.devicePixelRatio;
    if (dpr <= 0 || view.physicalSize.isEmpty) {
      return;
    }
    final logical = Size(
      view.physicalSize.width / dpr,
      view.physicalSize.height / dpr,
    );
    final (cacheW, cacheH) = backdropCachePx(
      logicalSize: logical,
      devicePixelRatio: dpr,
    );
    final provider = ResizeImage(
      const AssetImage(backdrop),
      width: cacheW,
      height: cacheH,
    );
    final stream = provider.resolve(
      ImageConfiguration(
        devicePixelRatio: dpr,
        size: logical,
      ),
    );
    final done = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        scheduleMicrotask(image.dispose);
        if (!done.isCompleted) {
          done.complete();
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        debugPrint('HomeAssets.precacheBackdrop failed: $error');
        if (!done.isCompleted) {
          done.complete();
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    await done.future;
  }
}
