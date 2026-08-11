import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/domain/home_assets.dart';

/// Full-bleed system wallpaper: HAL active file, else bundled Home backdrop.
class SystemWallpaperBackdrop extends StatelessWidget {
  const SystemWallpaperBackdrop({
    super.key,
    this.path,
    this.fit = BoxFit.cover,
  });

  /// Absolute path from [Wallpaper.activePath] (may be empty).
  final String? path;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = MediaQuery.sizeOf(context);
    final (cacheW, cacheH) = HomeAssets.backdropCachePx(
      logicalSize: size,
      devicePixelRatio: dpr,
    );
    final filePath = path?.trim() ?? '';
    if (filePath.isNotEmpty) {
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheW,
          cacheHeight: cacheH,
          errorBuilder: (_, __, ___) => _assetFallback(cacheW, cacheH),
        );
      }
    }
    return _assetFallback(cacheW, cacheH);
  }

  Widget _assetFallback(int cacheW, int cacheH) {
    return Image.asset(
      HomeAssets.backdrop,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      errorBuilder: (_, __, ___) =>
          const ColoredBox(color: Color(0xFF1A1A1A)),
    );
  }
}
