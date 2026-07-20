import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_backdrop_blur.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_sample_mode.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';
import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_glass_theme.dart';

/// Clip + [CyberBackdropBlur] chrome card (Home quick actions, panels).
///
/// Default sample mode is [CyberBlurSampleMode.realtime] (chrome / plan §6.3
/// OpenSpec override). Dialogs may pass [CyberBlurSampleMode.firstFrame].
class CyberCard extends StatelessWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.intensity,
    this.blurTint,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.onTap,
    this.clickSoundEnabled = true,
  });

  final Widget child;
  final double? width;
  final double? height;
  final CyberBlurSampleMode sampleMode;
  final CyberBlurIntensity? intensity;
  final CyberBlurTint? blurTint;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final VoidCallback? onTap;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = CyberGlassTheme.of(context);
    final radius =
        borderRadius ?? BorderRadius.circular(theme.cornerRadius);
    final border = Border.all(
      color: borderColor ?? theme.borderColor,
      width: borderWidth ?? theme.borderWidth,
    );

    Widget body = ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
        ),
        child: CyberBackdropBlur(
          sampleMode: sampleMode,
          intensity: intensity ?? theme.defaultIntensity,
          blurTint: blurTint ?? theme.defaultTint,
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (clickSoundEnabled) {
              CyberClickSoundRegistry.playClick();
            }
            onTap!();
          },
          borderRadius: radius,
          child: body,
        ),
      );
    }

    return body;
  }
}
