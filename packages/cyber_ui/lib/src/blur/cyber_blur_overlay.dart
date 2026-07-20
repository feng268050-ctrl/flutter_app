import 'package:flutter/material.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';

/// Resolves overlay like lws-ui `FrostBlurIntensity.resolveOverlayColor`:
/// intensity alpha + tint RGB.
Color cyberBlurOverlayColor({
  required CyberBlurIntensity intensity,
  required CyberBlurTint tint,
}) {
  return Color((intensity.overlayAlpha << 24) | tint.rgb);
}
