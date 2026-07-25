import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_panel_outline.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';

/// Frost `FrostButton` variants (`DEFAULT` → [standard]).
enum CyberButtonVariant { standard, primary, secondary, light }

enum CyberButtonSize { regular, small }

/// Frost `FrostButtonShape` — [rounded] is pill (half-height); [rectangle]
/// uses [CyberDimens.rectangleButtonCornerRadius].
enum CyberButtonShape { rounded, rectangle }

/// Frost-styled button (Material [InkWell] + shape; lws-ui `FrostButton`).
///
/// Default variant is [CyberButtonVariant.standard] (dark glass). Use
/// [CyberButtonVariant.primary] for confirm CTAs.
///
/// Default [shape] is [CyberButtonShape.rectangle] (existing HMI CTAs).
/// Frost XML defaults to rounded/pill — set [CyberButtonShape.rounded]
/// for parity (e.g. Device Information Check for Updates).
///
/// [borderGradientCenter] defaults to Frost button default
/// (`top-left-bottom-right`); Settings CTAs SHOULD vary this like cards.
///
/// Layout:
/// - Default: intrinsic width, fixed [size]/[height] height.
/// - [stretch]: max width + fixed height (Settings full-bleed CTAs in lists).
/// - [expand]: fill parent box (IME keycaps). Do **not** use inside
///   unbounded scroll children.
class CyberButton extends StatelessWidget {
  const CyberButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = CyberButtonVariant.standard,
    this.size = CyberButtonSize.regular,
    this.shape = CyberButtonShape.rectangle,
    this.clickSoundEnabled = true,
    this.expand = false,
    this.stretch = false,
    this.height,
    this.foregroundColor,
    this.onLongPress,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
    this.borderGradientColors,
    this.strokeWidth,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final CyberButtonVariant variant;
  final CyberButtonSize size;
  final CyberButtonShape shape;
  final bool clickSoundEnabled;

  /// When true, fill parent constraints (IME keycaps). Unbounded parents
  /// (e.g. [ListView] children) MUST NOT set this — use [stretch] instead.
  final bool expand;

  /// When true, take max cross-axis width with fixed button height.
  final bool stretch;

  /// Overrides [size] height when set (e.g. match a 36dp value chip).
  final double? height;

  /// Optional label/icon color override (e.g. IME accent backspace).
  final Color? foregroundColor;

  /// Frost `borderGradientCenter` for the 1dp stroke.
  final CyberBorderGradientCenter borderGradientCenter;

  /// Optional HL / mid / shadow override for the frost rim (e.g. brighter
  /// engineer Reset / Save pills). When null, uses [variant] defaults.
  final List<Color>? borderGradientColors;

  /// Stroke width override; defaults to [CyberDimens.buttonStrokeWidth].
  final double? strokeWidth;

  static const _disabledOpacity = 0.45;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final resolvedHeight = height ??
        (size == CyberButtonSize.small
            ? CyberDimens.actionButtonSmallHeight
            : CyberDimens.actionButtonHeight);
    final hPad = (expand || stretch)
        ? 0.0
        : (size == CyberButtonSize.small
            ? CyberDimens.actionButtonSmallPaddingHorizontal
            : CyberDimens.actionButtonPaddingHorizontal);
    final cornerRadius = shape == CyberButtonShape.rounded
        ? resolvedHeight / 2
        : CyberDimens.rectangleButtonCornerRadius;
    final radius = BorderRadius.circular(cornerRadius);
    final textColor = foregroundColor ?? _foreground(variant);
    final fontSize = size == CyberButtonSize.small
        ? CyberDimens.actionButtonSmallFontSize
        : CyberDimens.actionButtonFontSize;

    void handleTap() {
      if (onPressed == null) return;
      if (clickSoundEnabled) {
        CyberClickSoundRegistry.playClick();
      }
      onPressed!();
    }

    final outline = CyberPanelOutline(
      style: CyberPanelOutlineStyle.frostGradient,
      tone: variant == CyberButtonVariant.light
          ? CyberTone.light
          : CyberTone.dark,
      width: strokeWidth ?? CyberDimens.buttonStrokeWidth,
      cornerRadius: cornerRadius,
      gradientCenter: borderGradientCenter,
      gradientColorsOverride:
          borderGradientColors ?? _borderGradientColors(variant),
      uniformColor: _borderFlat(variant),
    );

    final label = DefaultTextStyle(
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.0,
      ),
      child: IconTheme(
        data: IconThemeData(color: textColor, size: expand ? 22 : 20),
        child: child,
      ),
    );

    final fillDecoration = BoxDecoration(
      borderRadius: radius,
      color: _solidFill(variant),
      gradient: _fillGradient(variant),
    );

    final Widget face;
    if (expand || stretch) {
      face = Stack(
        fit: StackFit.passthrough,
        children: [
          Ink(
            height: resolvedHeight,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: fillDecoration,
            child: Center(child: label),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: CyberFrostPanelOutlinePainter(outline),
              ),
            ),
          ),
        ],
      );
    } else {
      // Shrink-wrap face. [Text] expands to max width for wrapping — wrap in
      // a min-[Row] so the label keeps intrinsic width under loose constraints.
      final vPad = ((resolvedHeight - fontSize) / 2).clamp(0.0, resolvedHeight);
      face = CustomPaint(
        foregroundPainter: CyberFrostPanelOutlinePainter(outline),
        child: DecoratedBox(
          decoration: fillDecoration,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [label],
            ),
          ),
        ),
      );
    }

    final body = Opacity(
      opacity: enabled ? 1 : _disabledOpacity,
      child: face,
    );

    Widget childBox = body;
    if (expand) {
      childBox = SizedBox.expand(child: body);
    } else if (stretch) {
      childBox = SizedBox(
        width: double.infinity,
        height: resolvedHeight,
        child: body,
      );
    }

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? handleTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: radius,
        child: childBox,
      ),
    );

    if (expand || stretch) {
      return button;
    }
    // Shrink-wrap to label; [Align] widthFactor avoids [Ink]/[Container]
    // full-bleed under loose parent constraints.
    return Align(
      alignment: Alignment.center,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: button,
    );
  }

  static Color _foreground(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.secondary => CyberColors.buttonSecondaryText,
        CyberButtonVariant.standard ||
        CyberButtonVariant.primary ||
        CyberButtonVariant.light =>
          CyberColors.textPrimary,
      };

  static Color _borderFlat(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.primary => CyberColors.buttonPrimaryBorderMid,
        CyberButtonVariant.light => CyberColors.lightBorderHighlight,
        CyberButtonVariant.standard || CyberButtonVariant.secondary =>
          CyberColors.borderUniform,
      };

  static List<Color>? _borderGradientColors(CyberButtonVariant variant) =>
      switch (variant) {
        CyberButtonVariant.primary => const [
            CyberColors.buttonPrimaryBorderHighlight,
            CyberColors.buttonPrimaryBorderMid,
            CyberColors.buttonPrimaryBorderShadow,
          ],
        CyberButtonVariant.light => const [
            CyberColors.lightBorderHighlight,
            CyberColors.lightBorderMid,
            CyberColors.lightBorderShadow,
          ],
        CyberButtonVariant.standard || CyberButtonVariant.secondary => null,
      };

  static Color? _solidFill(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.primary => CyberColors.buttonPrimaryFill,
        _ => null,
      };

  static Gradient? _fillGradient(CyberButtonVariant variant) =>
      switch (variant) {
        CyberButtonVariant.primary => null,
        CyberButtonVariant.light => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CyberColors.lightFillTop,
              CyberColors.lightFillMid,
              CyberColors.lightFillBottom,
            ],
          ),
        CyberButtonVariant.standard || CyberButtonVariant.secondary =>
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CyberColors.fillTop,
              CyberColors.fillMid,
              CyberColors.fillBottom,
            ],
          ),
      };
}
