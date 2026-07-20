import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';

/// Visual tone for frost overlays (lws-ui `FrostTone`).
enum CyberTone {
  dark,
  light;

  CyberBlurTint get blurTint =>
      this == CyberTone.light ? CyberBlurTint.warm : CyberBlurTint.dark;

  CyberBlurIntensity get blurIntensity => this == CyberTone.light
      ? CyberBlurIntensity.extreme
      : CyberBlurIntensity.medium;
}
