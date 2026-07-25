import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_backdrop_blur.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_sample_mode.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';
import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_glass_theme.dart';
import 'package:cyber_ui/src/theme/cyber_panel_outline.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';

/// Frosted panel on Material [Card] + [CyberPanelOutline].
///
/// Default sample mode is [CyberBlurSampleMode.realtime] (Material Gaussian).
/// Pass [CyberBlurIntensity.transparent] for border-only (Frost settings cards).
/// Dialogs typically use [CyberBlurSampleMode.firstFrame].
class CyberCard extends StatelessWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.intensity,
    this.blurTint,
    this.tone,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.outlineStyle = CyberPanelOutlineStyle.frostGradient,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
    this.onTap,
    this.clickSoundEnabled = true,
  });

  final Widget child;
  final double? width;
  final double? height;
  final CyberBlurSampleMode sampleMode;
  final CyberBlurIntensity? intensity;
  final CyberBlurTint? blurTint;
  final CyberTone? tone;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final CyberPanelOutlineStyle outlineStyle;
  final CyberBorderGradientCenter borderGradientCenter;
  final VoidCallback? onTap;
  final bool clickSoundEnabled;

  /// Readable uniform stroke (legacy alias for settings call sites).
  static const defaultBorderColor = CyberColors.borderUniform;

  @override
  Widget build(BuildContext context) {
    final theme = CyberGlassTheme.of(context);
    final resolvedTone = tone ?? theme.tone;
    final resolvedIntensity = intensity ?? resolvedTone.blurIntensity;
    final corner = borderRadius?.topLeft.x ?? theme.cornerRadius;
    final stroke = borderWidth ?? theme.borderWidth;
    final outline = CyberPanelOutline(
      style: outlineStyle,
      tone: resolvedTone,
      width: stroke < 1.0 ? 1.0 : stroke,
      cornerRadius: corner,
      uniformColor: borderColor,
      gradientCenter: borderGradientCenter,
    );

    final fill = resolvedIntensity == CyberBlurIntensity.transparent
        ? Colors.white.withOpacity(0.06)
        : Colors.transparent;

    Widget body = CyberOutlinedPanel(
      outline: outline,
      color: fill,
      child: CyberBackdropBlur(
        sampleMode: sampleMode,
        intensity: resolvedIntensity,
        blurTint: blurTint ?? resolvedTone.blurTint,
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        borderRadius: outline.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (clickSoundEnabled) {
              CyberClickSoundRegistry.playClick();
            }
            onTap!();
          },
          borderRadius: outline.borderRadius,
          child: body,
        ),
      );
    }

    return body;
  }
}
