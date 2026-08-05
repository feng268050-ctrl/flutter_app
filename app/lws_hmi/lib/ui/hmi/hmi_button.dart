import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

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
    this.variant = CyberButtonVariant.standard,
    this.shape = CyberButtonShape.rectangle,
    this.icon,
    this.leading,
    this.trailing,
    this.clickSoundEnabled = true,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
    this.borderGradientColors,
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

  final CyberButtonVariant variant;
  final CyberButtonShape shape;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool clickSoundEnabled;
  final CyberBorderGradientCenter borderGradientCenter;
  final List<Color>? borderGradientColors;
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

    final child = _HmiButtonLabel(
      label: label,
      style: labelStyle,
      iconSize: metrics.iconSize,
      buttonHeight: metrics.height,
      horizontalPadding: metrics.horizontalPadding,
      icon: icon,
      leading: leading,
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
      HmiButtonWidthPolicy.adaptive => ConstrainedBox(
          constraints: BoxConstraints(minWidth: metrics.minWidth),
          child: IntrinsicWidth(child: sized),
        ),
    };
  }

  static CyberButtonSize _cyberSizeFor(HmiButtonSize size) {
    return switch (size) {
      HmiButtonSize.mini => CyberButtonSize.mini,
      HmiButtonSize.small => CyberButtonSize.small,
      HmiButtonSize.medium => CyberButtonSize.medium,
      HmiButtonSize.large || HmiButtonSize.hero => CyberButtonSize.large,
    };
  }
}

final class _HmiButtonLabel extends StatelessWidget {
  const _HmiButtonLabel({
    required this.label,
    required this.style,
    required this.iconSize,
    required this.buttonHeight,
    required this.horizontalPadding,
    this.icon,
    this.leading,
    this.trailing,
  });

  final String label;
  final TextStyle style;
  final double iconSize;
  final double buttonHeight;
  final double horizontalPadding;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (icon == null
            ? null
            : Icon(icon, size: iconSize, color: style.color ?? Colors.white));

    // Icon/leading without trailing: label centered on the full button;
    // icon left inset equals top/bottom inset (Reset / Save Favorite).
    if (lead != null && trailing == null) {
      final edgeInset = ((buttonHeight - iconSize) / 2).clamp(0.0, buttonHeight);
      return SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
            Positioned(
              left: edgeInset,
              top: edgeInset,
              width: iconSize,
              height: iconSize,
              child: icon != null
                  ? Icon(
                      icon,
                      size: iconSize,
                      color: style.color ?? Colors.white,
                    )
                  : FittedBox(fit: BoxFit.contain, child: lead),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (lead != null) ...[
            lead,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
