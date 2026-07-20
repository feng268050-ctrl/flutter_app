/// Overlay tint presets aligned with lws-ui `FrostBlurTint`.
enum CyberBlurTint {
  /// Neutral dark RGB `#101012` (`frost_blur_tint`).
  dark,

  /// Warm cream / white RGB `#FFFFFF` (`frost_blur_tint_warm`).
  warm,
}

extension CyberBlurTintRgb on CyberBlurTint {
  /// RGB without alpha; alpha comes from [CyberBlurIntensity.overlayAlpha].
  int get rgb => switch (this) {
        CyberBlurTint.dark => 0x101012,
        CyberBlurTint.warm => 0xFFFFFF,
      };
}
