import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';

/// ThemeExtension seam for glass tokens.
@immutable
class CyberGlassTheme extends ThemeExtension<CyberGlassTheme> {
  const CyberGlassTheme({
    this.defaultIntensity = CyberBlurIntensity.medium,
    this.defaultTint = CyberBlurTint.dark,
    this.tone = CyberTone.dark,
    this.borderColor = CyberColors.borderHighlight,
    this.borderWidth = CyberDimens.borderWidth,
    this.cornerRadius = CyberDimens.cornerRadius,
  });

  final CyberBlurIntensity defaultIntensity;
  final CyberBlurTint defaultTint;
  final CyberTone tone;
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
    CyberTone? tone,
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
  }) {
    return CyberGlassTheme(
      defaultIntensity: defaultIntensity ?? this.defaultIntensity,
      defaultTint: defaultTint ?? this.defaultTint,
      tone: tone ?? this.tone,
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
      tone: t < 0.5 ? tone : other.tone,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      cornerRadius: cornerRadius + (other.cornerRadius - cornerRadius) * t,
    );
  }
}
