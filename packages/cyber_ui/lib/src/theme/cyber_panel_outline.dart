import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';

/// Frost `BorderGradientCenter` — highlight placement for panel / button strokes.
enum CyberBorderGradientCenter {
  /// Diagonal: radial highlights at top-left + bottom-right.
  topLeftBottomRight,

  /// Diagonal: radial highlights at bottom-left + top-right.
  bottomLeftTopRight,

  /// Same opposing pair as [bottomLeftTopRight] (Frost alias).
  topRightBottomLeft,

  /// Axis: linear H–S–H (highlights at top and bottom).
  topBottom,

  /// Axis: linear H–S–H (highlights at left and right).
  leftRight,

  /// Flat single-color stroke.
  uniform;

  /// Settings list habit: rotate directions so adjacent cards differ
  /// (lws-ui Common Settings / Device Info pattern).
  static CyberBorderGradientCenter settingsCardAt(int index) {
    const cycle = <CyberBorderGradientCenter>[
      CyberBorderGradientCenter.topBottom,
      CyberBorderGradientCenter.topLeftBottomRight,
      CyberBorderGradientCenter.bottomLeftTopRight,
      CyberBorderGradientCenter.topRightBottomLeft,
    ];
    return cycle[index % cycle.length];
  }

  bool get isAxis =>
      this == CyberBorderGradientCenter.topBottom ||
      this == CyberBorderGradientCenter.leftRight;

  bool get isDiagonal =>
      this == CyberBorderGradientCenter.topLeftBottomRight ||
      this == CyberBorderGradientCenter.bottomLeftTopRight ||
      this == CyberBorderGradientCenter.topRightBottomLeft;
}

extension CyberBorderGradientCenterGeom on CyberBorderGradientCenter {
  /// Begin/end for axis [LinearGradient] (symmetric H–S–H stops).
  (Alignment begin, Alignment end)? get axisAlignments => switch (this) {
        CyberBorderGradientCenter.topBottom => (
            Alignment.topCenter,
            Alignment.bottomCenter,
          ),
        CyberBorderGradientCenter.leftRight => (
            Alignment.centerLeft,
            Alignment.centerRight,
          ),
        _ => null,
      };

  /// Opposing corner centers for diagonal radial highlights (normalized 0–1).
  List<Alignment>? get diagonalCornerAlignments => switch (this) {
        CyberBorderGradientCenter.topLeftBottomRight => const [
            Alignment.topLeft,
            Alignment.bottomRight,
          ],
        CyberBorderGradientCenter.bottomLeftTopRight ||
        CyberBorderGradientCenter.topRightBottomLeft =>
          const [
            Alignment.bottomLeft,
            Alignment.topRight,
          ],
        _ => null,
      };
}

/// How panel chrome draws its outline.
enum CyberPanelOutlineStyle {
  /// Single [BorderSide] (Material [RoundedRectangleBorder.side]).
  uniform,

  /// Frost `PanelBorderPainter` — bidirectional HL/shadow on round-rect stroke.
  frostGradient,
}

/// Shared outline tokens for [CyberCard] / settings panels / buttons.
class CyberPanelOutline {
  const CyberPanelOutline({
    this.style = CyberPanelOutlineStyle.frostGradient,
    this.tone = CyberTone.dark,
    this.width = CyberDimens.borderWidth,
    this.cornerRadius = CyberDimens.cornerRadius,
    this.uniformColor,
    this.gradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
    this.gradientColorsOverride,
  });

  final CyberPanelOutlineStyle style;
  final CyberTone tone;
  final double width;
  final double cornerRadius;
  final Color? uniformColor;
  final CyberBorderGradientCenter gradientCenter;
  final List<Color>? gradientColorsOverride;

  BorderRadius get borderRadius => BorderRadius.circular(cornerRadius);

  bool get usesGradientStroke =>
      style == CyberPanelOutlineStyle.frostGradient &&
      gradientCenter != CyberBorderGradientCenter.uniform;

  Color get resolvedUniformColor =>
      uniformColor ??
      (tone == CyberTone.light
          ? CyberColors.lightBorderHighlight
          : CyberColors.borderUniform);

  /// Material shape side when not using a gradient stroke.
  BorderSide get materialSide => BorderSide(
        color: resolvedUniformColor,
        width: width < 1.0 ? 1.0 : width,
      );

  /// HL / mid / shadow stops (override or tone defaults).
  List<Color> get gradientColors =>
      gradientColorsOverride ??
      (tone == CyberTone.light
          ? const [
              CyberColors.lightBorderHighlight,
              CyberColors.lightBorderMid,
              CyberColors.lightBorderShadow,
            ]
          : const [
              CyberColors.borderHighlight,
              CyberColors.borderMid,
              CyberColors.borderShadow,
            ]);

  Color get highlightColor => gradientColors[0];

  Color get midColor =>
      gradientColors.length > 1 ? gradientColors[1] : gradientColors[0];

  Color get shadowColor =>
      gradientColors.length > 2 ? gradientColors[2] : midColor;
}

/// Draws a rounded-rect stroke with Frost bidirectional borders.
///
/// - Axis (`topBottom` / `leftRight`): one [LinearGradient] with H–S–H stops.
/// - Diagonal: shadow baseline + two opposing [RadialGradient] corner HL.
///   Radius = [cornerHighlightFraction] × short side (not long-edge boosted).
/// - Uniform: solid stroke.
class CyberFrostPanelOutlinePainter extends CustomPainter {
  CyberFrostPanelOutlinePainter(this.outline);

  final CyberPanelOutline outline;

  static const _axisStops = <double>[0.0, 0.20, 0.5, 0.80, 1.0];

  /// Frost dark-tone radial stops; soft tail kept a bit brighter so the HL
  /// reads along the edge (same stop positions as PanelBorderPainter).
  static const _radialStops = <double>[0.0, 0.38, 0.76, 1.0];

  /// Diagonal corner radial radius = this × min(width, height).
  static const cornerHighlightFraction = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final w = outline.width;
    if (w <= 0 || size.isEmpty) return;
    final inset = w * 0.5;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final radius = math.max(0.0, outline.cornerRadius - inset);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;

    final center = outline.gradientCenter;
    if (center == CyberBorderGradientCenter.uniform ||
        outline.style == CyberPanelOutlineStyle.uniform) {
      stroke.color = outline.resolvedUniformColor;
      canvas.drawRRect(rrect, stroke);
      return;
    }

    if (center.isAxis) {
      _paintAxis(canvas, rrect, rect, stroke);
      return;
    }

    if (center.isDiagonal) {
      _paintDiagonal(canvas, rrect, rect, stroke);
    }
  }

  void _paintAxis(Canvas canvas, RRect rrect, Rect rect, Paint stroke) {
    final (begin, end) = outline.gradientCenter.axisAlignments!;
    final hl = outline.highlightColor;
    final shadow = outline.shadowColor;
    final blend = Color.lerp(shadow, hl, 0.38)!;
    stroke.shader = LinearGradient(
      begin: begin,
      end: end,
      colors: [hl, blend, shadow, blend, hl],
      stops: _axisStops,
    ).createShader(rect);
    canvas.drawRRect(rrect, stroke);
  }

  void _paintDiagonal(Canvas canvas, RRect rrect, Rect rect, Paint stroke) {
    // Frost drawLocalizedBaseline — shadow blended with mid for readable edge.
    final shadow = _blend(outline.shadowColor, outline.midColor, 0.28);
    stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = shadow;
    canvas.drawRRect(rrect, stroke);

    final corners = outline.gradientCenter.diagonalCornerAlignments!;
    final shortSide = math.min(rect.width, rect.height);
    final radialR = shortSide * cornerHighlightFraction;
    // Frost withMinimumAlpha(…, 0xD4/0xB0/0x80) — raw token HL is ~0x77 and
    // reads as almost flat without boosting on dark HMI.
    final bright = _withMinAlpha(outline.highlightColor, 0xD4);
    final midHl = _withMinAlpha(outline.highlightColor, 0xB0);
    final softHl = _withMinAlpha(outline.highlightColor, 0x80);
    final midBlend = _blend(shadow, midHl, 0.52);
    // Slightly stronger soft blend than Frost's 0.08 so the HL tail travels
    // farther along the stroke before vanishing into the baseline.
    final softBlend = _blend(shadow, softHl, 0.22);

    for (final alignment in corners) {
      final center = alignment.withinRect(rect);
      stroke.shader = ui.Gradient.radial(
        center,
        radialR,
        <Color>[
          bright,
          midBlend,
          softBlend,
          const Color(0x00000000),
        ],
        _radialStops,
      );
      canvas.drawRRect(rrect, stroke);
    }
  }

  static Color _withMinAlpha(Color color, int minAlphaByte) {
    if (color.alpha >= minAlphaByte) return color;
    return color.withAlpha(minAlphaByte);
  }

  static Color _blend(Color from, Color to, double toFraction) {
    final fromFraction = 1.0 - toFraction;
    return Color.fromARGB(
      (from.alpha * fromFraction + to.alpha * toFraction)
          .round()
          .clamp(0, 255),
      (from.red * fromFraction + to.red * toFraction).round().clamp(0, 255),
      (from.green * fromFraction + to.green * toFraction)
          .round()
          .clamp(0, 255),
      (from.blue * fromFraction + to.blue * toFraction).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(covariant CyberFrostPanelOutlinePainter oldDelegate) {
    return oldDelegate.outline.style != outline.style ||
        oldDelegate.outline.tone != outline.tone ||
        oldDelegate.outline.width != outline.width ||
        oldDelegate.outline.cornerRadius != outline.cornerRadius ||
        oldDelegate.outline.uniformColor != outline.uniformColor ||
        oldDelegate.outline.gradientCenter != outline.gradientCenter ||
        oldDelegate.outline.gradientColorsOverride !=
            outline.gradientColorsOverride;
  }
}

/// Material [Card] + optional Frost gradient outline overlay.
class CyberOutlinedPanel extends StatelessWidget {
  const CyberOutlinedPanel({
    super.key,
    required this.child,
    this.outline = const CyberPanelOutline(),
    this.color = Colors.transparent,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final CyberPanelOutline outline;
  final Color color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius = outline.borderRadius;
    final useGradient = outline.usesGradientStroke;
    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: useGradient ? BorderSide.none : outline.materialSide,
      ),
      child: child,
    );
    if (!useGradient) return card;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        card,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CyberFrostPanelOutlinePainter(outline),
            ),
          ),
        ),
      ],
    );
  }
}
