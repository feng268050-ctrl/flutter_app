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
    final labelStyle = metrics.textStyle.copyWith(
      color: metrics.textStyle.color ?? Colors.white,
      height: 1.0,
    );

    final child = _HmiButtonLabel(
      label: label,
      style: labelStyle,
      iconSize: metrics.iconSize,
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
    required this.horizontalPadding,
    this.icon,
    this.leading,
    this.trailing,
  });

  final String label;
  final TextStyle style;
  final double iconSize;
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

    // Icon/leading without trailing: `[gap][icon][gap][label][gap]` so left
    // inset equals icon↔label spacing (Reset / Save / wire CTAs).
    if (lead != null && trailing == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
          final textW = painter.width;
          var drawIcon = iconSize;
          var gap = (constraints.maxWidth - drawIcon - textW) / 3;
          if (gap < 0) {
            drawIcon = (constraints.maxWidth - textW).clamp(0.0, iconSize);
            gap = (constraints.maxWidth - drawIcon - textW) / 3;
            if (gap < 0) {
              gap = 0;
              drawIcon = (constraints.maxWidth - textW).clamp(0.0, iconSize);
            }
          }
          final row = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: gap),
              if (drawIcon > 0)
                SizedBox(
                  width: drawIcon,
                  height: drawIcon,
                  child: icon != null
                      ? Icon(
                          icon,
                          size: drawIcon,
                          color: style.color ?? Colors.white,
                        )
                      : FittedBox(fit: BoxFit.contain, child: lead),
                ),
              SizedBox(width: gap),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: style,
              ),
              SizedBox(width: gap),
            ],
          );
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: row,
          );
        },
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
