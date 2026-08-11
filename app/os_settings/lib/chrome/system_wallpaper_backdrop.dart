import 'dart:io';

import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';

/// Full-bleed system wallpaper from HAL, with dark gradient fallback.
class SystemWallpaperBackdrop extends StatelessWidget {
  const SystemWallpaperBackdrop({super.key, this.fit = BoxFit.cover});

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path =
        OsSettingsScope.maybeOf(context)?.services.wallpaper().activePath.trim() ?? '';
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const _DarkGradientBackdrop(),
        );
      }
    }
    return const _DarkGradientBackdrop();
  }
}

class _DarkGradientBackdrop extends StatelessWidget {
  const _DarkGradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1C22),
            Color(0xFF101218),
            Color(0xFF0C0E12),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
