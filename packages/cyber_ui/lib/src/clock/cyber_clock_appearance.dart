import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';

/// Appearance tokens for Cyber clock chrome (lws-ui `FrostClockAppearance`).
abstract final class CyberClockAppearance {
  /// Glyph vertical scale (lws-ui `TEXT_VERTICAL_SCALE`).
  static const verticalScale = 1.2;

  /// Backdrop capture downscale divisor.
  static const captureScaleDivisor = 5.0;

  static const fillTop = Color(0x88FFFFFF);
  static const fillMid = Color(0x78FFFCFA);
  static const fillBottom = Color(0x68FFF8F6);
  static const milkOverlay = Color(0x40FFFCF8);
  static const borderShadow = Color(0x55000000);

  static const blurIntensity = CyberBlurIntensity.extreme;
  static const blurTint = CyberBlurTint.warm;
}

/// Documents Cyber clock frost capabilities for product Apps.
///
/// **Glyph-clip live blur:** true per-glyph clip + live frost is not fully
/// guaranteed on RK3566. Product clocks SHOULD keep the area around glyphs
/// fully transparent (no rectangular frost plate). Prefer glyph fill overlays
/// and/or frozen capture clipped with `dstIn` (see App `HomeClock`).
abstract final class CyberClockNotes {
  static const glyphClipLiveBlurSupported = false;
  static const glyphClipLiveBlurNote =
      'True glyph-clipped live blur is approximated on RK3566; '
      'do not place a rectangular CyberBackdropBlur behind clock glyphs — '
      'use fill overlays and/or frozen capture with dstIn.';
}
