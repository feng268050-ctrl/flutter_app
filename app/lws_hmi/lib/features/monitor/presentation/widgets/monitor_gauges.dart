import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      final labelY =
          center.dy + labelBandRadius * math.sin(angle);
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
    final step = majorTickEvery > 0
        ? majorTickEvery
        : math.max(1.0, span / 10);
    final out = <double>[];
    for (var v = min; v <= max + 1e-9; v += step) {
      out.add(v > max ? max : v);
    }
    if (out.isEmpty || (out.last - max).abs() > 1e-6) {
      out.add(max);
    }
    return out;
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
    this.titleLine1 = 'Laser',
    this.titleLine2 = 'Current',
    this.size = 280,
    this.trackWidth = 16,
    /// Step between labeled majors; `≤0` → `max/10` (11 marks).
    this.majorTickEvery = 0,
    this.progressColor = const Color(0xFF4FC3F7),
    this.trackColor = const Color(0x33FFFFFF),
    this.tickColor = Colors.white,
    this.rimStrokeColor = Colors.white,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  final double value;
  final double min;
  final double max;
  final String unit;
  final String titleLine1;
  final String titleLine2;
  final double size;
  final double trackWidth;
  final double majorTickEvery;
  final Color progressColor;
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

  @override
  Widget build(BuildContext context) {
    final span = (widget.max - widget.min).abs();
    // Machine Status tab content: +2 over size-relative bases.
    final labelStyle = TextStyle(
      color: widget.tickColor,
      fontSize: widget.size * (18 / 200) + 2,
      fontWeight: FontWeight.w400,
      height: 1.0,
    );
    final geom = CurrentArcGaugeGeom.compute(
      side: widget.size,
      trackWidth: widget.trackWidth,
      maxValue: widget.max,
      labelStyle: labelStyle,
    );
    final majors = CurrentArcGaugeGeom.majorValues(
      min: widget.min,
      max: widget.max,
      majorTickEvery: widget.majorTickEvery,
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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final v = _animation.value.clamp(widget.min, widget.max);
        final t = span <= 0 ? 0.0 : (v - widget.min) / span;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          // Horseshoe dial is optically high in a centered square — shift the
          // whole ink (arc + ticks + labels + readout) so T/B match the box.
          child: Transform.translate(
            offset: Offset(0, opticalDy),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CurrentArcPainter(
                    progress: t,
                    geom: geom,
                    majors: majors,
                    min: widget.min,
                    max: widget.max,
                    progressColor: widget.progressColor,
                    trackColor: widget.trackColor,
                    tickColor: widget.tickColor,
                    rimStrokeColor: widget.rimStrokeColor,
                  ),
                ),
                // Tick numerals as real Text widgets (lws-ui horizontal, radial
                // centers) — prefer Flutter layout over Canvas.drawText.
                for (final mark in majors)
                  _MajorTickLabel(
                    geom: geom,
                    value: mark,
                    min: widget.min,
                    max: widget.max,
                    text: _formatTick(mark),
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
                                text: _formatValue(v),
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
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: widget.size * 0.055 + 2,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          widget.titleLine2,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: widget.size * 0.055 + 2,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal label centered on the radial mark (lws-ui `drawText` ALIGN_CENTER).
final class _MajorTickLabel extends StatelessWidget {
  const _MajorTickLabel({
    required this.geom,
    required this.value,
    required this.min,
    required this.max,
    required this.text,
    required this.style,
  });

  final CurrentArcGaugeGeom geom;
  final double value;
  final double min;
  final double max;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    if (span <= 0) {
      return const SizedBox.shrink();
    }
    final t = ((value - min) / span).clamp(0.0, 1.0);
    final angle = MonitorArcGeometry.angleForProgress(t);
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

class _CurrentArcPainter extends CustomPainter {
  _CurrentArcPainter({
    required this.progress,
    required this.geom,
    required this.majors,
    required this.min,
    required this.max,
    required this.progressColor,
    required this.trackColor,
    required this.tickColor,
    required this.rimStrokeColor,
  });

  final double progress;
  final CurrentArcGaugeGeom geom;
  final List<double> majors;
  final double min;
  final double max;
  final Color progressColor;
  final Color trackColor;
  final Color tickColor;
  final Color rimStrokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final span = max - min;
    if (span <= 0) {
      return;
    }

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

    // 4. Major ticks only (no minor ticks).
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = math.max(1.5, size.width * (2 / 200))
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    for (final mark in majors) {
      final mt = ((mark - min) / span).clamp(0.0, 1.0);
      final angle = MonitorArcGeometry.angleForProgress(mt);
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
  }

  @override
  bool shouldRepaint(covariant _CurrentArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.geom.ringRadius != geom.ringRadius ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.rimStrokeColor != rimStrokeColor ||
        oldDelegate.majors.length != majors.length;
  }
}
