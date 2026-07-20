/// Preset blur strength aligned with lws-ui `FrostBlurIntensity`.
enum CyberBlurIntensity {
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
  /// Gaussian sigma (lws-ui blur radius px, capped ~25).
  double get sigma => switch (this) {
        CyberBlurIntensity.low => 12,
        CyberBlurIntensity.medium => 20,
        CyberBlurIntensity.high => 23,
        CyberBlurIntensity.extreme => 25,
      };

  /// Overlay alpha applied over [CyberBlurTint] RGB (lws-ui `overlayAlpha`).
  int get overlayAlpha => switch (this) {
        CyberBlurIntensity.low => 0x15,
        CyberBlurIntensity.medium => 0x30,
        CyberBlurIntensity.high => 0x40,
        CyberBlurIntensity.extreme => 0x50,
      };
}
