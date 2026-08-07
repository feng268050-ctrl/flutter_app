import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_panel_outline.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';

/// Panel border + optional vertical fill (lws-ui border painter stand-in).
///
/// Uses Flutter gradients rather than full bitmap shaders (RK3566-friendly).
class CyberPanelBorder {
  const CyberPanelBorder({
    this.tone = CyberTone.dark,
    this.width = CyberDimens.borderWidth,
    this.cornerRadius = CyberDimens.cornerRadius,
  });

  final CyberTone tone;
  final double width;
  final double cornerRadius;

  BorderRadius get borderRadius => BorderRadius.circular(cornerRadius);

  List<Color> get borderGradientColors => tone == CyberTone.light
      ? const [
          CyberColors.lightBorderHighlight,
          CyberColors.lightBorderMid,
          CyberColors.lightBorderShadow,
        ]
      : const [
          CyberColors.borderHighlight,
          CyberColors.borderMid,
          CyberColors.borderShadow,
        ];

  List<Color> get fillGradientColors => tone == CyberTone.light
      ? const [
          CyberColors.lightFillTop,
          CyberColors.lightFillMid,
          CyberColors.lightFillBottom,
        ]
      : const [
          CyberColors.fillTop,
          CyberColors.fillMid,
          CyberColors.fillBottom,
        ];

  /// Simple uniform border color (cards that don't need gradient stroke).
  Color get flatBorderColor => borderGradientColors.first;

  /// Tip/dialog rim — 1px white highlight at 50% opacity.
  ///
  /// Prefer [tipRimOutline] + [CyberFrostPanelOutlinePainter] over a
  /// [BoxDecoration] border inside [ClipRRect] (stroke gets clipped away).
  Color get tipRimColor => CyberColors.tipRimHighlight;

  /// Uniform 1px orange outline for tip / Operation Failed overlays.
  CyberPanelOutline get tipRimOutline => CyberPanelOutline(
        style: CyberPanelOutlineStyle.uniform,
        tone: tone,
        width: width,
        cornerRadius: cornerRadius,
        uniformColor: tipRimColor,
      );

  /// LIGHT cream dialog container — 1px opaque black.
  Color get creamDialogRimColor => CyberColors.creamDialogRim;

  CyberPanelOutline get creamDialogRimOutline => CyberPanelOutline(
        style: CyberPanelOutlineStyle.uniform,
        tone: tone,
        width: width,
        cornerRadius: cornerRadius,
        uniformColor: creamDialogRimColor,
      );

  BoxDecoration fillDecoration({bool includeBorder = true}) {
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: fillGradientColors,
      ),
      border: includeBorder
          ? Border.all(color: flatBorderColor, width: width)
          : null,
    );
  }

  /// Gradient stroke approximated as highlight border (full dual-tone later).
  BoxDecoration chromeDecoration() => fillDecoration(includeBorder: true);
}
