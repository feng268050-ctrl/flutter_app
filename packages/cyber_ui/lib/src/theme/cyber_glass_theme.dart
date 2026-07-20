import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';

/// ThemeExtension seam for glass tokens (P3.0 stub — expand in later polish).
@immutable
class CyberGlassTheme extends ThemeExtension<CyberGlassTheme> {
  const CyberGlassTheme({
    this.defaultIntensity = CyberBlurIntensity.medium,
    this.defaultTint = CyberBlurTint.dark,
    this.borderColor = const Color(0x55FFFFFF),
    this.borderWidth = 1,
    this.cornerRadius = 18,
  });

  final CyberBlurIntensity defaultIntensity;
  final CyberBlurTint defaultTint;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;

  static CyberGlassTheme of(BuildContext context) {
    return Theme.of(context).extension<CyberGlassTheme>() ??
        const CyberGlassTheme();
  }

  @override
  CyberGlassTheme copyWith({
    CyberBlurIntensity? defaultIntensity,
    CyberBlurTint? defaultTint,
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
  }) {
    return CyberGlassTheme(
      defaultIntensity: defaultIntensity ?? this.defaultIntensity,
      defaultTint: defaultTint ?? this.defaultTint,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  @override
  CyberGlassTheme lerp(ThemeExtension<CyberGlassTheme>? other, double t) {
    if (other is! CyberGlassTheme) {
      return this;
    }
    return CyberGlassTheme(
      defaultIntensity:
          t < 0.5 ? defaultIntensity : other.defaultIntensity,
      defaultTint: t < 0.5 ? defaultTint : other.defaultTint,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      cornerRadius: cornerRadius + (other.cornerRadius - cornerRadius) * t,
    );
  }
}
