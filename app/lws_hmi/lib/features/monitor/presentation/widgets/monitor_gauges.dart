import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_display_typography.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';

enum GaugeVisualStyle {
  horseshoe,
  integratedRing,
}

@immutable
final class GaugeArcConfig {
  const GaugeArcConfig({
    required this.startAngle,
    required this.sweepAngle,
  });

  final double startAngle;
  final double sweepAngle;

  double get complementSweepAngle => 2 * math.pi - sweepAngle;

  double angleForProgress(double progress) =>
      startAngle + sweepAngle * progress.clamp(0.0, 1.0);
}

abstract final class GaugeArcPresets {
  static const horseshoe = GaugeArcConfig(
    startAngle: 135 * math.pi / 180,
    sweepAngle: 270 * math.pi / 180,
  );

  static const integratedRing = GaugeArcConfig(
    startAngle: 140 * math.pi / 180,
    sweepAngle: 260 * math.pi / 180,
  );
}

/// Shared 270° arc geometry: start bottom-left → end bottom-right, clockwise.
abstract final class MonitorArcGeometry {
  /// Flutter [Canvas.drawArc] start (radians from +X, clockwise).
  static const startAngle = 135 * math.pi / 180;

  /// Sweep of the full track (270°).
  static const sweepAngle = 270 * math.pi / 180;

  static double angleForProgress(double t) =>
      startAngle + sweepAngle * t.clamp(0.0, 1.0);

  static Offset pointOnArc(Offset center, double radius, double angle) {
    // Flutter arcs: 0 = +X, clockwise positive → x = cos(a), y = sin(a).
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  /// Closed annular sector with true concentric arcs and flat radial cuts.
  ///
  /// Progress rendering owns this geometry. Bottom-cabin rounding stays in
  /// [IntegratedRingGaugeGeometry.bottomCabinPath] and must not be introduced
  /// here as end caps: caps extend beyond the requested progress angles and
  /// make a constant-thickness circular ring appear elliptical.
  static Path flatAnnularSector({
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required double startAngle,
    required double sweepAngle,
  }) {
    assert(outerRadius > innerRadius);
    assert(sweepAngle > 0);
    final endAngle = startAngle + sweepAngle;
    final outerStart = pointOnArc(center, outerRadius, startAngle);
    final innerEnd = pointOnArc(center, innerRadius, endAngle);
    return Path()
      ..moveTo(outerStart.dx, outerStart.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
      )
      // Flat terminal cut at the live progress angle.
      ..lineTo(innerEnd.dx, innerEnd.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        endAngle,
        -sweepAngle,
        false,
      )
      // Flat terminal cut at the fixed start angle.
      ..lineTo(outerStart.dx, outerStart.dy)
      ..close();
  }
}

/// 0–100% gauge: 270° open arc, gray track, colored progress, white end dot.
class PercentArcGauge extends StatefulWidget {
  const PercentArcGauge({
    super.key,
    required this.value,
    this.size = 180,
    this.strokeWidth = 18,
    this.progressColor = const Color(0xFFFF0000),
    this.trackColor = const Color(0xFF5A5A5A),
    this.animationDuration = const Duration(milliseconds: 600),
    this.textStyle,
  });

  /// Percent in 0–100.
  final double value;
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;
  final Duration animationDuration;
  final TextStyle? textStyle;

  @override
  State<PercentArcGauge> createState() => _PercentArcGaugeState();
}

class _PercentArcGaugeState extends State<PercentArcGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.value.clamp(0.0, 100.0);
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = AlwaysStoppedAnimation(_to);
  }

  @override
  void didUpdateWidget(PercentArcGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = widget.animationDuration;
    }
    final next = widget.value.clamp(0.0, 100.0);
    if (next != _to) {
      _from = _animation.value;
      _to = next;
      _animation = Tween<double>(begin: _from, end: _to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        TextStyle(
          color: Colors.white,
          // Work Info tab content: +2 over size-relative base.
          fontSize: widget.size * 0.22 + 2,
          fontWeight: FontWeight.w700,
        );
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final v = _animation.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _PercentArcPainter(
              percent: v,
              strokeWidth: widget.strokeWidth,
              progressColor: widget.progressColor,
              trackColor: widget.trackColor,
            ),
            child: Center(
              child: Text('${v.round()}%', style: style),
            ),
          ),
        );
      },
    );
  }
}

class _PercentArcPainter extends CustomPainter {
  _PercentArcPainter({
    required this.percent,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  final double percent;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final t = (percent / 100).clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(
      rect,
      MonitorArcGeometry.startAngle,
      MonitorArcGeometry.sweepAngle,
      false,
      trackPaint,
    );

    if (t > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawArc(
        rect,
        MonitorArcGeometry.startAngle,
        MonitorArcGeometry.sweepAngle * t,
        false,
        progressPaint,
      );
    }

    // Indicator always visible (including at 0% = arc start).
    final tip = MonitorArcGeometry.pointOnArc(
      center,
      radius,
      MonitorArcGeometry.angleForProgress(t),
    );
    final tipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(tip, strokeWidth * 0.55, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _PercentArcPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Outside-in geometry for [CurrentArcGauge] — lws-ui `CircleProgressView`.
///
/// Track outer rim is flush with major-tick **inner** ends; a 1px rim stroke
/// connects those tick feet along the arc.
final class CurrentArcGaugeGeom {
  const CurrentArcGaugeGeom({
    required this.center,
    required this.ringRadius,
    required this.trackWidth,
    required this.scaleInnerRadius,
    required this.scaleOuterRadius,
    required this.labelBandRadius,
  });

  final Offset center;

  /// Progress/track stroke path radius (stroke centered on this circle).
  final double ringRadius;
  final double trackWidth;

  /// Major tick foot (flush with track outer rim).
  final double scaleInnerRadius;

  /// Major tick tip (toward labels).
  final double scaleOuterRadius;

  /// Radial band where label **centers** sit (horizontal [Text]).
  final double labelBandRadius;

  /// Track outer rim — same as [scaleInnerRadius]; rim stroke hugs this.
  double get trackOuterRimRadius => scaleInnerRadius;

  /// lws-ui defaults scaled to [side]: tick 12/200, gap 18/200, edge 3/200.
  ///
  /// [radiusBoost] grows the progress arc (and tick feet) by this many logical
  /// pixels after the outside-in fit — used to counteract wide labels (e.g. 1500).
  static CurrentArcGaugeGeom compute({
    required double side,
    required double trackWidth,
    required double maxValue,
    required TextStyle labelStyle,
    double radiusBoost = 25,
  }) {
    final center = Offset(side / 2, side / 2);
    final edgePad = side * (3 / 200);
    final tickLen = side * (12 / 200);
    final labelGap = side * (18 / 200);
    final strokeW = trackWidth;

    final painter = TextPainter(
      text: TextSpan(
        text: maxValue.round().toString(),
        style: labelStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final textHalfH = painter.height / 2;
    final widestHalf = painter.width / 2;
    final labelClearance = math.max(widestHalf, textHalfH) + edgePad;
    var labelBand = math.max(side / 2 - labelClearance, strokeW);
    var scaleOuter = math.max(labelBand - labelGap, strokeW);
    var scaleInner = math.max(scaleOuter - tickLen, strokeW / 2);
    var ringRadius = math.max(scaleInner - strokeW / 2, strokeW / 2);

    if (radiusBoost != 0) {
      final maxLabelBand = side / 2 - edgePad;
      final room = math.max(0.0, maxLabelBand - labelBand);
      final boost = math.min(radiusBoost, room);
      ringRadius += boost;
      scaleInner += boost;
      scaleOuter += boost;
      labelBand += boost;
    }

    return CurrentArcGaugeGeom(
      center: center,
      ringRadius: ringRadius,
      trackWidth: strokeW,
      scaleInnerRadius: scaleInner,
      scaleOuterRadius: scaleOuter,
      labelBandRadius: labelBand,
    );
  }

  /// Dy to shift the horseshoe ink so its vertical bbox is centered in the
  /// square. Open-bottom 270° arcs sit optically high when the box is centered.
  double opticalVerticalOffset({required double labelHalfHeight}) {
    var minY = double.infinity;
    var maxY = -double.infinity;
    final trackOuter = ringRadius + trackWidth / 2;
    for (var i = 0; i <= 24; i++) {
      final t = i / 24.0;
      final angle = MonitorArcGeometry.angleForProgress(t);
      final labelY = center.dy + labelBandRadius * math.sin(angle);
      minY = math.min(minY, labelY - labelHalfHeight);
      maxY = math.max(maxY, labelY + labelHalfHeight);
      final trackY = center.dy + trackOuter * math.sin(angle);
      minY = math.min(minY, trackY);
      maxY = math.max(maxY, trackY);
    }
    return center.dy - (minY + maxY) / 2;
  }

  /// Labeled majors: `0, step, 2·step, …, max` (lws-ui `max/10` when step≤0).
  static List<double> majorValues({
    required double min,
    required double max,
    required double majorTickEvery,
  }) {
    final span = max - min;
    if (span <= 0) {
      return const [];
    }
    final step = majorTickEvery > 0 ? majorTickEvery : math.max(1.0, span / 10);
    final out = <double>[];
    for (var v = min; v <= max + 1e-9; v += step) {
      out.add(v > max ? max : v);
    }
    if (out.isEmpty || (out.last - max).abs() > 1e-6) {
      out.add(max);
    }
    return out;
  }

  /// Positions [count] marks evenly from the start (0) to the end (1) of
  /// the gauge arc. Used when a product scale keeps selected labels while
  /// preserving equal visual intervals instead of numeric proportionality.
  static List<double> evenlySpacedProgresses(int count) {
    if (count <= 0) {
      return const [];
    }
    if (count == 1) {
      return const [0];
    }
    return List<double>.generate(count, (index) => index / (count - 1));
  }

  /// Inserts [countBetween] evenly spaced positions between each adjacent
  /// pair of values in [majorProgresses].
  static List<double> intermediateProgresses(
    List<double> majorProgresses,
    int countBetween,
  ) {
    if (countBetween <= 0 || majorProgresses.length < 2) {
      return const [];
    }
    final progresses = <double>[];
    for (var index = 0; index < majorProgresses.length - 1; index++) {
      final start = majorProgresses[index];
      final end = majorProgresses[index + 1];
      final step = (end - start) / (countBetween + 1);
      for (var minor = 1; minor <= countBetween; minor++) {
        progresses.add(start + step * minor);
      }
    }
    return progresses;
  }
}

/// Machine-status gauge: majors-only ticks + rim arc + Flutter-laid-out labels.
///
/// Parity: lws-ui `CircleProgressView` (no minor ticks; rim stroke at tick feet).
class CurrentArcGauge extends StatefulWidget {
  const CurrentArcGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.unit = 'A',
    this.title,
    this.titleLine1 = 'Laser',
    this.titleLine2 = 'Current',
    this.visualStyle = GaugeVisualStyle.horseshoe,
    this.size = 280,
    this.trackWidth = 16,

    /// Step between labeled majors; `≤0` → `max/10` (11 marks).
    this.majorTickEvery = 0,
    this.evenlySpacedTickValues,
    this.minorTicksBetweenMajors = 0,
    this.geometryMaxLabelValue,
    this.progressColor = const Color(0xFF4FC3F7),
    this.ringSurfaceColor = const Color(0xFF181818),
    this.trackColor = const Color(0x33FFFFFF),
    this.tickColor = Colors.white,
    this.rimStrokeColor = Colors.white,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  final double value;
  final double min;
  final double max;
  final String unit;

  /// Gauge name used by [GaugeVisualStyle.integratedRing].
  ///
  /// The bottom cabin renders at most two centered lines. When omitted, the
  /// legacy title lines are joined with a line break for compatibility.
  final String? title;
  final String titleLine1;
  final String titleLine2;
  final GaugeVisualStyle visualStyle;
  final double size;
  final double trackWidth;
  final double majorTickEvery;

  /// Complete tick-and-label scale rendered at equal visual intervals.
  ///
  /// When null, ticks use their numeric position from [majorTickEvery]. This
  /// lets a product retain selected values without leaving unlabeled ticks.
  final List<double>? evenlySpacedTickValues;

  /// Number of shorter, unlabeled ticks inserted between adjacent major ticks.
  ///
  /// The minor marks use the same arc geometry as the major scale, so they
  /// remain evenly spaced even when [evenlySpacedTickValues] is used.
  /// [GaugeVisualStyle.integratedRing] deliberately renders major ticks only.
  final int minorTicksBetweenMajors;

  /// Reference numeral used only to resolve the arc radius.
  ///
  /// A paired gauge can set this to its neighbour's maximum so both rings use
  /// identical geometry while retaining their own tick labels and values.
  final double? geometryMaxLabelValue;
  final Color progressColor;
  final Color ringSurfaceColor;
  final Color trackColor;
  final Color tickColor;
  final Color rimStrokeColor;
  final Duration animationDuration;

  @override
  State<CurrentArcGauge> createState() => _CurrentArcGaugeState();
}

class _CurrentArcGaugeState extends State<CurrentArcGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = AlwaysStoppedAnimation(_to);
  }

  @override
  void didUpdateWidget(CurrentArcGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = widget.animationDuration;
    }
    if (widget.value != _to) {
      _from = _animation.value;
      _to = widget.value;
      _animation = Tween<double>(begin: _from, end: _to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    return v.toStringAsFixed(1);
  }

  String _formatTick(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    return v.toStringAsFixed(0);
  }

  String get _gaugeTitle {
    final title = widget.title?.trim();
    if (title != null && title.isNotEmpty) {
      return _twoLineGaugeTitle(title);
    }
    return _twoLineGaugeTitle(
      [widget.titleLine1, widget.titleLine2]
          .where((part) => part.trim().isNotEmpty)
          .join('\n'),
    );
  }

  String _twoLineGaugeTitle(String rawTitle) {
    final words = rawTitle
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length <= 1) {
      return words.isEmpty ? '' : words.single;
    }

    var bestSplit = 1;
    var smallestDifference = double.infinity;
    for (var split = 1; split < words.length; split++) {
      final firstLength = words.take(split).join(' ').length;
      final secondLength = words.skip(split).join(' ').length;
      final difference = (firstLength - secondLength).abs().toDouble();
      if (difference < smallestDifference) {
        smallestDifference = difference;
        bestSplit = split;
      }
    }
    return '${words.take(bestSplit).join(' ')}\n'
        '${words.skip(bestSplit).join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final span = (widget.max - widget.min).abs();
    final majors = CurrentArcGaugeGeom.majorValues(
      min: widget.min,
      max: widget.max,
      majorTickEvery: widget.majorTickEvery,
    );
    final tickValues = widget.evenlySpacedTickValues ?? majors;
    final tickProgresses = widget.evenlySpacedTickValues == null
        ? majors
            .map((mark) => ((mark - widget.min) / span).clamp(0.0, 1.0))
            .toList(growable: false)
        : CurrentArcGaugeGeom.evenlySpacedProgresses(tickValues.length);
    // Integrated Ring is a major-only scale. Preserve optional minor marks
    // exclusively for the legacy horseshoe visual style.
    final minorTickProgresses = widget.visualStyle == GaugeVisualStyle.horseshoe
        ? CurrentArcGaugeGeom.intermediateProgresses(
            tickProgresses,
            widget.minorTicksBetweenMajors,
          )
        : const <double>[];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final v = _animation.value.clamp(widget.min, widget.max);
        final t = span <= 0 ? 0.0 : (v - widget.min) / span;
        return switch (widget.visualStyle) {
          GaugeVisualStyle.horseshoe => _buildHorseshoe(
              context,
              value: v,
              progress: t,
              tickValues: tickValues,
              tickProgresses: tickProgresses,
              minorTickProgresses: minorTickProgresses,
            ),
          GaugeVisualStyle.integratedRing => _buildIntegratedRing(
              context,
              value: v,
              progress: t,
              tickValues: tickValues,
              tickProgresses: tickProgresses,
            ),
        };
      },
    );
  }

  double get _geometryScale => (widget.size / 260).clamp(0.68, 1.0);

  Widget _buildHorseshoe(
    BuildContext context, {
    required double value,
    required double progress,
    required List<double> tickValues,
    required List<double> tickProgresses,
    required List<double> minorTickProgresses,
  }) {
    // Legacy lws-ui gauge dimensions stay unchanged in horseshoe mode.
    final labelStyle = TextStyle(
      color: widget.tickColor,
      fontSize: widget.size * (18 / 200) + 2,
      fontWeight: FontWeight.w400,
      height: 1,
    );
    final geom = CurrentArcGaugeGeom.compute(
      side: widget.size,
      trackWidth: widget.trackWidth,
      maxValue: widget.geometryMaxLabelValue ?? widget.max,
      labelStyle: labelStyle,
    );
    final labelProbe = TextPainter(
      text: TextSpan(
        text: widget.max.round().toString(),
        style: labelStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final opticalDy = geom.opticalVerticalOffset(
      labelHalfHeight: labelProbe.height / 2,
    );
    final titleStyle = HmiDisplayTypography.gaugeName.copyWith(
      color: Colors.white70,
      fontSize: HmiDisplayTypography.gaugeNameSize * _geometryScale,
    );
    final titleScaler = HmiTextScale.displayTextScalerOf(context);

    return SizedBox.square(
      dimension: widget.size,
      child: Transform.translate(
        offset: Offset(0, opticalDy),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: _CurrentArcPainter(
                progress: progress,
                geom: geom,
                tickProgresses: tickProgresses,
                minorTickProgresses: minorTickProgresses,
                progressColor: widget.progressColor,
                trackColor: widget.trackColor,
                tickColor: widget.tickColor,
                rimStrokeColor: widget.rimStrokeColor,
              ),
            ),
            for (var index = 0; index < tickValues.length; index++)
              _MajorTickLabel(
                geom: geom,
                progress: tickProgresses[index],
                text: _formatTick(tickValues[index]),
                style: labelStyle,
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: widget.size * 0.06),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _formatValue(value),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.size * 0.14 + 2,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: ' ${widget.unit}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: widget.size * 0.07 + 2,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: widget.size * 0.02),
                    Text(
                      widget.titleLine1,
                      textScaler: titleScaler,
                      style: titleStyle,
                    ),
                    Text(
                      widget.titleLine2,
                      textScaler: titleScaler,
                      style: titleStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegratedRing(
    BuildContext context, {
    required double value,
    required double progress,
    required List<double> tickValues,
    required List<double> tickProgresses,
  }) {
    final geom = IntegratedRingGaugeGeometry.compute(
      side: widget.size,
    );
    final geometryScale = _geometryScale;
    final textScaler = HmiTextScale.displayTextScalerOf(context);
    final tickStyle = HmiDisplayTypography.gaugeTickLabel.copyWith(
      color: widget.tickColor.withValues(alpha: 0.88),
      fontSize: HmiDisplayTypography.gaugeTickLabelSize * geometryScale,
    );

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size.square(widget.size),
            painter: _IntegratedRingGaugePainter(
              progress: progress,
              geom: geom,
              progressColor: widget.progressColor,
              ringSurfaceColor: widget.ringSurfaceColor,
            ),
          ),
          CustomPaint(
            size: Size.square(widget.size),
            painter: _GaugeBottomCabinPainter(geom: geom),
          ),
          CustomPaint(
            size: Size.square(widget.size),
            painter: _IntegratedRingGaugeForegroundPainter(
              geom: geom,
              tickProgresses: tickProgresses,
              tickColor: widget.tickColor,
              rimStrokeColor: widget.rimStrokeColor,
            ),
          ),
          for (var index = 0; index < tickValues.length; index++)
            _IntegratedRingTickLabel(
              geom: geom,
              progress: tickProgresses[index],
              text: _formatTick(tickValues[index]),
              style: tickStyle,
              textScaler: textScaler,
            ),
          Positioned(
            left: widget.size * 0.25,
            right: widget.size * 0.25,
            top: widget.size * 0.34,
            height: widget.size * 0.31,
            child: _GaugeCenterReadout(
              value: _formatValue(value),
              unit: widget.unit,
              geometryScale: geometryScale,
              textScaler: textScaler,
            ),
          ),
          Positioned(
            left: widget.size * 0.15,
            right: widget.size * 0.15,
            bottom: 0,
            height: widget.size * 0.36,
            child: _GaugeBottomInfoCabin(
              key: const ValueKey<String>('gauge-bottom-info-cabin'),
              label: _gaugeTitle,
              geometryScale: geometryScale,
              textScaler: textScaler,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed-ratio geometry shared by both machine-status integrated-ring gauges.
final class IntegratedRingGaugeGeometry {
  const IntegratedRingGaugeGeometry({
    required this.center,
    required this.ringRadius,
    required this.ringThickness,
    required this.outerRimRadius,
    required this.labelBandRadius,
    required this.bottomCabinInnerRadius,
  }) : assert(outerRimRadius > ringRadius + ringThickness / 2);

  final Offset center;
  final double ringRadius;
  final double ringThickness;
  final double outerRimRadius;
  final double labelBandRadius;
  final double bottomCabinInnerRadius;

  double get ringSectorOuterRadius => ringRadius + ringThickness / 2;
  double get ringInnerRadius => ringRadius - ringThickness / 2;

  /// Temporary plain-sector baseline: clear each terminal scale angle by 16°.
  /// Inner and outer joins intentionally share this angle so the cabin sides
  /// are straight radial cuts, with no rounded corner occupation.
  static const double bottomCabinTerminalClearance = 16 * math.pi / 180;

  /// Fixed radial spacing between the dark Ring Sector and outer scale rim.
  double get outerRimRadiusDelta => outerRimRadius - ringSectorOuterRadius;

  /// Major ticks occupy only the external scale band: Outer Rim → Ring Sector.
  double get majorTickOuterRadius => outerRimRadius;
  double get majorTickInnerRadius => ringSectorOuterRadius;

  Rect get ringSectorOuterBounds =>
      Rect.fromCircle(center: center, radius: ringSectorOuterRadius);

  Rect get outerRimBounds =>
      Rect.fromCircle(center: center, radius: outerRimRadius);

  /// The cabin bottom remains concentric with the outer rim. Outer joins stay
  /// inset from the scale terminals so the 1px outlines do not collide.
  Rect get bottomCabinOuterBounds => outerRimBounds;

  /// Exact identity prevents a radial seam between progress and center dial.
  double get centerDialRadius => ringInnerRadius;

  /// Bottom tangent of the center dial. The cabin concavity is intentionally
  /// lifted above this baseline so the cabin has visible vertical mass.
  double get centerDialBaselineY => center.dy + centerDialRadius;

  /// Lowest point of the cabin's inner concave edge (at 90°).
  double get bottomCabinInnerApexY => center.dy + bottomCabinInnerRadius;

  double get bottomCabinInnerLiftAboveDialBaseline =>
      centerDialBaselineY - bottomCabinInnerApexY;

  double get bottomCabinScaleRightAngle =>
      GaugeArcPresets.integratedRing.startAngle +
      GaugeArcPresets.integratedRing.sweepAngle;

  double get bottomCabinScaleLeftAngle =>
      GaugeArcPresets.integratedRing.startAngle;

  double get bottomCabinRightAngle =>
      bottomCabinScaleRightAngle + bottomCabinTerminalClearance;

  double get bottomCabinLeftAngle =>
      bottomCabinScaleLeftAngle - bottomCabinTerminalClearance;

  double get bottomCabinSweepAngle =>
      bottomCabinLeftAngle + 2 * math.pi - bottomCabinRightAngle;

  /// Intermediate spacing-validation silhouette: two concentric arcs joined
  /// by two straight radial sides. Corner curves can be reintroduced only
  /// after this baseline clears terminal ticks and labels at production size.
  Path bottomCabinPath() {
    final innerLeft = MonitorArcGeometry.pointOnArc(
      center,
      bottomCabinInnerRadius,
      bottomCabinLeftAngle,
    );
    final outerRight = MonitorArcGeometry.pointOnArc(
      center,
      outerRimRadius,
      bottomCabinRightAngle,
    );

    return Path()
      ..moveTo(innerLeft.dx, innerLeft.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: bottomCabinInnerRadius),
        bottomCabinLeftAngle,
        -bottomCabinSweepAngle,
        false,
      )
      ..lineTo(outerRight.dx, outerRight.dy)
      ..arcTo(
        bottomCabinOuterBounds,
        bottomCabinRightAngle,
        bottomCabinSweepAngle,
        false,
      )
      ..lineTo(innerLeft.dx, innerLeft.dy)
      ..close();
  }

  static IntegratedRingGaugeGeometry compute({
    required double side,
  }) {
    final ringRadius = side * 0.355;
    final ringThickness = side * 0.18;
    return IntegratedRingGaugeGeometry(
      center: Offset(side / 2, side / 2),
      ringRadius: ringRadius,
      ringThickness: ringThickness,
      outerRimRadius: side * 0.48,
      labelBandRadius: side * 0.345,
      bottomCabinInnerRadius: side * 0.22,
    );
  }
}

final class _IntegratedRingTickLabel extends StatelessWidget {
  const _IntegratedRingTickLabel({
    required this.geom,
    required this.progress,
    required this.text,
    required this.style,
    required this.textScaler,
  });

  final IntegratedRingGaugeGeometry geom;
  final double progress;
  final String text;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    final angle = GaugeArcPresets.integratedRing.angleForProgress(progress);
    final anchor = MonitorArcGeometry.pointOnArc(
      geom.center,
      geom.labelBandRadius,
      angle,
    );
    return Positioned(
      left: 0,
      top: 0,
      child: Transform.translate(
        offset: anchor,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            textScaler: textScaler,
            style: style,
          ),
        ),
      ),
    );
  }
}

final class _GaugeCenterReadout extends StatelessWidget {
  const _GaugeCenterReadout({
    required this.value,
    required this.unit,
    required this.geometryScale,
    required this.textScaler,
  });

  final String value;
  final String unit;
  final double geometryScale;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    final valueStyle = HmiDisplayTypography.gaugeValue.copyWith(
      color: Colors.white,
      fontSize: HmiDisplayTypography.gaugeValueSize * geometryScale,
    );
    final unitStyle = HmiDisplayTypography.gaugeUnit.copyWith(
      color: const Color(0xCCFFFFFF),
      fontSize: HmiDisplayTypography.gaugeUnitSize * geometryScale,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              textScaler: textScaler,
              style: valueStyle,
            ),
          ),
        ),
        SizedBox(height: 5 * geometryScale),
        Text(
          unit,
          maxLines: 1,
          textAlign: TextAlign.center,
          textScaler: textScaler,
          style: unitStyle,
        ),
      ],
    );
  }
}

final class _GaugeBottomInfoCabin extends StatelessWidget {
  const _GaugeBottomInfoCabin({
    super.key,
    required this.label,
    required this.geometryScale,
    required this.textScaler,
  });

  final String label;
  final double geometryScale;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep both lines below the cabin's center concavity. The bottom
        // inset follows the curved edge so glyphs stay inside the fan at
        // every supported gauge size and display text scale.
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18 * geometryScale,
            constraints.maxHeight * 0.37,
            18 * geometryScale,
            constraints.maxHeight * 0.12,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 2,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                textScaler: textScaler,
                style: HmiDisplayTypography.gaugeName.copyWith(
                  color: Colors.white,
                  fontSize: HmiDisplayTypography.gaugeNameSize * geometryScale,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugeBottomCabinPainter extends CustomPainter {
  const _GaugeBottomCabinPainter({required this.geom});

  final IntegratedRingGaugeGeometry geom;

  Path _cabinPath() => geom.bottomCabinPath();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cabinPath();
    final fill = Paint()
      ..color = const Color(0xFF050506)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);

    final border = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _GaugeBottomCabinPainter oldDelegate) {
    return oldDelegate.geom.center != geom.center ||
        oldDelegate.geom.outerRimRadius != geom.outerRimRadius ||
        oldDelegate.geom.bottomCabinInnerRadius != geom.bottomCabinInnerRadius;
  }
}

/// Horizontal label centered on the radial mark (lws-ui `drawText` ALIGN_CENTER).
final class _MajorTickLabel extends StatelessWidget {
  const _MajorTickLabel({
    required this.geom,
    required this.progress,
    required this.text,
    required this.style,
  });

  final CurrentArcGaugeGeom geom;
  final double progress;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final angle = MonitorArcGeometry.angleForProgress(progress);
    final anchor = MonitorArcGeometry.pointOnArc(
      geom.center,
      geom.labelBandRadius,
      angle,
    );
    return Positioned(
      left: 0,
      top: 0,
      child: Transform.translate(
        offset: anchor,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _IntegratedRingGaugePainter extends CustomPainter {
  _IntegratedRingGaugePainter({
    required this.progress,
    required this.geom,
    required this.progressColor,
    required this.ringSurfaceColor,
  });

  final double progress;
  final IntegratedRingGaugeGeometry geom;
  final Color progressColor;
  final Color ringSurfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    const arc = GaugeArcPresets.integratedRing;

    // 1. A complete circular surface stabilizes the gauge silhouette. The
    //    black center dial later reveals this surface as one continuous ring.
    final backgroundPaint = Paint()
      ..color = ringSurfaceColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawOval(geom.ringSectorOuterBounds, backgroundPaint);

    // 2. Flat-cut annular sector: both curved edges remain true concentric
    //    circles and both terminals are straight radial lines. Cabin rounding
    //    is intentionally owned by bottomCabinPath(), not this progress path.
    final t = progress.clamp(0.0, 1.0);
    if (t > 0) {
      final sector = MonitorArcGeometry.flatAnnularSector(
        center: geom.center,
        innerRadius: geom.centerDialRadius,
        outerRadius: geom.ringSectorOuterRadius,
        startAngle: arc.startAngle,
        sweepAngle: arc.sweepAngle * t,
      );
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(sector, progressPaint);
    }

    // 3. Pure-black center circle: no gradient, glow, or white outline.
    final dialPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(geom.center, geom.centerDialRadius, dialPaint);
  }

  @override
  bool shouldRepaint(covariant _IntegratedRingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.geom.center != geom.center ||
        oldDelegate.geom.ringRadius != geom.ringRadius ||
        oldDelegate.geom.ringThickness != geom.ringThickness ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.ringSurfaceColor != ringSurfaceColor;
  }
}

/// Circular foreground stays above the name-cabin surface. The scale rim and
/// cabin remain concentric while retaining a deliberate angular separation.
class _IntegratedRingGaugeForegroundPainter extends CustomPainter {
  _IntegratedRingGaugeForegroundPainter({
    required this.geom,
    required this.tickProgresses,
    required this.tickColor,
    required this.rimStrokeColor,
  });

  final IntegratedRingGaugeGeometry geom;
  final List<double> tickProgresses;
  final Color tickColor;
  final Color rimStrokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const arc = GaugeArcPresets.integratedRing;
    final majorPaint = Paint()
      ..color = tickColor.withValues(alpha: 0.92)
      ..strokeWidth = math.max(1.6, size.width * 0.007)
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Hard-clip Major Tick paint to the Outer Rim circle. Each mark starts
    // on the rim and is drawn radially toward the center; no tick pixels can
    // extend beyond the outer circular boundary.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(geom.outerRimBounds),
      doAntiAlias: true,
    );
    for (final tickProgress in tickProgresses) {
      final angle = arc.angleForProgress(tickProgress);
      canvas.drawLine(
        MonitorArcGeometry.pointOnArc(
          geom.center,
          geom.majorTickOuterRadius,
          angle,
        ),
        MonitorArcGeometry.pointOnArc(
          geom.center,
          geom.majorTickInnerRadius,
          angle,
        ),
        majorPaint,
      );
    }
    canvas.restore();

    // Paint the effective-range rim last so it remains the clean outermost
    // boundary and visually caps every inward tick at the same radius.
    final rimPaint = Paint()
      ..color = rimStrokeColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    canvas.drawArc(
      geom.outerRimBounds,
      arc.startAngle,
      arc.sweepAngle,
      false,
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _IntegratedRingGaugeForegroundPainter oldDelegate,
  ) {
    return oldDelegate.geom.center != geom.center ||
        oldDelegate.geom.outerRimRadius != geom.outerRimRadius ||
        oldDelegate.geom.majorTickInnerRadius != geom.majorTickInnerRadius ||
        oldDelegate.geom.majorTickOuterRadius != geom.majorTickOuterRadius ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.rimStrokeColor != rimStrokeColor ||
        !listEquals(oldDelegate.tickProgresses, tickProgresses);
  }
}

class _CurrentArcPainter extends CustomPainter {
  _CurrentArcPainter({
    required this.progress,
    required this.geom,
    required this.tickProgresses,
    required this.minorTickProgresses,
    required this.progressColor,
    required this.trackColor,
    required this.tickColor,
    required this.rimStrokeColor,
  });

  final double progress;
  final CurrentArcGaugeGeom geom;
  final List<double> tickProgresses;
  final List<double> minorTickProgresses;
  final Color progressColor;
  final Color trackColor;
  final Color tickColor;
  final Color rimStrokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect =
        Rect.fromCircle(center: geom.center, radius: geom.ringRadius);

    // 1. Background track.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = geom.trackWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      trackRect,
      MonitorArcGeometry.startAngle,
      MonitorArcGeometry.sweepAngle,
      false,
      trackPaint,
    );

    // 2. Progress.
    final t = progress.clamp(0.0, 1.0);
    if (t > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = geom.trackWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawArc(
        trackRect,
        MonitorArcGeometry.startAngle,
        MonitorArcGeometry.sweepAngle * t,
        false,
        progressPaint,
      );
    }

    // 3. 1px rim stroke — connects major-tick feet, flush with track outer edge
    //    (lws-ui `drawRingOuterStroke`).
    final rimRect = Rect.fromCircle(
      center: geom.center,
      radius: geom.trackOuterRimRadius,
    );
    final rimPaint = Paint()
      ..color = rimStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      rimRect,
      MonitorArcGeometry.startAngle,
      MonitorArcGeometry.sweepAngle,
      false,
      rimPaint,
    );

    // 4. Major ticks, paired with the numeric labels rendered above.
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = math.max(1.5, size.width * (2 / 200))
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    for (final tickProgress in tickProgresses) {
      final angle = MonitorArcGeometry.angleForProgress(tickProgress);
      final p0 = MonitorArcGeometry.pointOnArc(
        geom.center,
        geom.scaleInnerRadius,
        angle,
      );
      final p1 = MonitorArcGeometry.pointOnArc(
        geom.center,
        geom.scaleOuterRadius,
        angle,
      );
      canvas.drawLine(p0, p1, tickPaint);
    }

    // 5. Optional half-step ticks. They share the major ticks' outer anchor
    // but are shorter and deliberately do not have number labels.
    if (minorTickProgresses.isNotEmpty) {
      final minorTickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = math.max(1.25, size.width * (1.5 / 200))
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;
      final minorOuterRadius = geom.scaleInnerRadius +
          (geom.scaleOuterRadius - geom.scaleInnerRadius) * 0.58;
      for (final tickProgress in minorTickProgresses) {
        final angle = MonitorArcGeometry.angleForProgress(tickProgress);
        final p0 = MonitorArcGeometry.pointOnArc(
          geom.center,
          geom.scaleInnerRadius,
          angle,
        );
        final p1 = MonitorArcGeometry.pointOnArc(
          geom.center,
          minorOuterRadius,
          angle,
        );
        canvas.drawLine(p0, p1, minorTickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurrentArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.geom.ringRadius != geom.ringRadius ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.rimStrokeColor != rimStrokeColor ||
        !listEquals(oldDelegate.tickProgresses, tickProgresses) ||
        !listEquals(oldDelegate.minorTickProgresses, minorTickProgresses);
  }
}
