/// Preset blur strength aligned with lws-ui `FrostBlurIntensity`.
enum CyberBlurIntensity {
  /// Border-only chrome — no fill overlay and no Gaussian blur
  /// (lws-ui `FrostBlurIntensity.TRANSPARENT`).
  transparent,

  /// Light frost (~LOW).
  low,

  /// Default card blur (~MIDDLE).
  medium,

  /// Stronger (~HIGH).
  high,

  /// Maximum frost — home quick actions (~EXTREME).
  extreme,
}

extension CyberBlurIntensityValues on CyberBlurIntensity {
  /// Whether this intensity applies a Gaussian blur pass.
  bool get usesBackdropBlur =>
      this != CyberBlurIntensity.transparent && sigma > 0;

  /// Whether a tint overlay should be painted.
  bool get drawsOverlay => overlayAlpha > 0;

  /// Gaussian sigma (lws-ui blur radius px, capped ~25).
  double get sigma => switch (this) {
        CyberBlurIntensity.transparent => 0,
        CyberBlurIntensity.low => 12,
        CyberBlurIntensity.medium => 20,
        CyberBlurIntensity.high => 23,
        CyberBlurIntensity.extreme => 25,
      };

  /// Overlay alpha applied over [CyberBlurTint] RGB (lws-ui `overlayAlpha`).
  int get overlayAlpha => switch (this) {
        CyberBlurIntensity.transparent => 0,
        CyberBlurIntensity.low => 0x15,
        CyberBlurIntensity.medium => 0x30,
        CyberBlurIntensity.high => 0x40,
        CyberBlurIntensity.extreme => 0x50,
      };
}
