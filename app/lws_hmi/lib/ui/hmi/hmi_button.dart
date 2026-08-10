import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_adaptive_icon_label.dart';

/// App-level button that binds FrostUI 100% metrics to [CyberButton] chrome.
///
/// Pages choose [size] + [widthPolicy]; they must not override label [fontSize].
final class HmiButton extends StatelessWidget {
  const HmiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = HmiButtonSize.medium,
    this.widthPolicy = HmiButtonWidthPolicy.adaptive,
    this.width,
    this.horizontalPadding,
    this.variant = CyberButtonVariant.standard,
    this.shape = CyberButtonShape.rectangle,
    this.icon,
    this.leading,
    this.trailing,
    this.clickSoundEnabled = true,
    this.borderGradientCenter = CyberBorderGradientCenter.uniform,
    this.borderGradientColors,
    this.borderColor,
    this.strokeWidth,
    this.paintFill = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final HmiButtonSize size;
  final HmiButtonWidthPolicy widthPolicy;

  /// Required for [HmiButtonWidthPolicy.fixed] / [HmiButtonWidthPolicy.equal]
  /// when the parent does not already constrain width.
  final double? width;

  /// Optional content padding override for a constrained button group.
  final double? horizontalPadding;

  final CyberButtonVariant variant;
  final CyberButtonShape shape;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  final bool clickSoundEnabled;

  /// Legacy; buttons default to [CyberColors.buttonRim] (70% white) or
  /// [CyberColors.buttonPrimaryRim] (60%) when [variant] is primary.
  final CyberBorderGradientCenter borderGradientCenter;
  final List<Color>? borderGradientColors;

  /// Flat stroke override; default follows [CyberButton] rim tokens.
  final Color? borderColor;
  final double? strokeWidth;
  final bool paintFill;

  @override
  Widget build(BuildContext context) {
    final typography = context.hmiTypography;
    final metrics = HmiButtonMetrics.forSize(size, typography);
    final foreground = switch (variant) {
      CyberButtonVariant.secondary => CyberColors.buttonSecondaryText,
      _ => metrics.textStyle.color ?? Colors.white,
    };
    final labelStyle = metrics.textStyle.copyWith(
      color: foreground,
      height: 1.0,
    );

    final resolvedLeading = leading ??
        (icon == null
            ? null
            : Icon(icon, size: metrics.iconSize, color: foreground));
    final resolvedPadding = horizontalPadding ?? metrics.horizontalPadding;
    final child = HmiAdaptiveIconLabel(
      label: label,
      style: labelStyle,
      iconSize: metrics.iconSize,
      buttonHeight: metrics.height,
      horizontalPadding: resolvedPadding,
      leading: resolvedLeading,
      trailing: trailing,
    );

    // Always stretch so CyberButton uses [height] directly (not shrink-wrap
    // vPad based on Cyber default fontSize).
    final cyber = CyberButton(
      onPressed: onPressed,
      variant: variant,
      size: _cyberSizeFor(size),
      shape: shape,
      clickSoundEnabled: clickSoundEnabled,
      height: metrics.height,
      stretch: true,
      borderGradientCenter: borderGradientCenter,
      borderGradientColors: borderGradientColors,
      borderColor: borderColor,
      strokeWidth: strokeWidth,
      paintFill: paintFill,
      child: child,
    );

    final sized = SizedBox(height: metrics.height, child: cyber);

    return switch (widthPolicy) {
      HmiButtonWidthPolicy.fill => sized,
      HmiButtonWidthPolicy.fixed || HmiButtonWidthPolicy.equal => SizedBox(
          width: width ?? metrics.minWidth,
          height: metrics.height,
          child: cyber,
        ),
      HmiButtonWidthPolicy.adaptive => SizedBox(
          width: math.max(
            metrics.minWidth,
            HmiIconLabelLayout.groupedRequiredWidth(
              labelWidth:
                  HmiIconLabelLayout.textWidth(context, label, labelStyle),
              horizontalPadding: resolvedPadding,
              iconSize: metrics.iconSize,
              hasLeading: resolvedLeading != null,
              hasTrailing: trailing != null,
            ),
          ),
          height: metrics.height,
          child: cyber,
        ),
    };
  }

  static CyberButtonSize _cyberSizeFor(HmiButtonSize size) {
    return switch (size) {
      HmiButtonSize.mini => CyberButtonSize.mini,
      HmiButtonSize.small => CyberButtonSize.small,
      HmiButtonSize.medium => CyberButtonSize.medium,
      HmiButtonSize.large ||
      HmiButtonSize.hero ||
      HmiButtonSize.jumbo =>
        CyberButtonSize.large,
    };
  }
}
