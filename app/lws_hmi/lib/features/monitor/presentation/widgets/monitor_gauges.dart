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
          fontSize: widget.size * 0.22,
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

/// Machine-status current gauge: tick ring + inner progress + center value/title.
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
    this.majorTickEvery = 10,
    this.minorTickEvery = 1,
    this.progressColor = const Color(0xFF4FC3F7),
    this.trackColor = const Color(0xFF2A3550),
    this.tickColor = const Color(0xFF8A93A8),
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
  final double minorTickEvery;
  final Color progressColor;
  final Color trackColor;
  final Color tickColor;
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

  @override
  Widget build(BuildContext context) {
    final span = (widget.max - widget.min).abs();
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final v = _animation.value.clamp(widget.min, widget.max);
        final t = span <= 0 ? 0.0 : (v - widget.min) / span;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CurrentArcPainter(
              progress: t,
              min: widget.min,
              max: widget.max,
              trackWidth: widget.trackWidth,
              majorTickEvery: widget.majorTickEvery,
              minorTickEvery: widget.minorTickEvery,
              progressColor: widget.progressColor,
              trackColor: widget.trackColor,
              tickColor: widget.tickColor,
            ),
            child: Center(
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
                              fontSize: widget.size * 0.14,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: ' ${widget.unit}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: widget.size * 0.07,
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
                        fontSize: widget.size * 0.055,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      widget.titleLine2,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: widget.size * 0.055,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CurrentArcPainter extends CustomPainter {
  _CurrentArcPainter({
    required this.progress,
    required this.min,
    required this.max,
    required this.trackWidth,
    required this.majorTickEvery,
    required this.minorTickEvery,
    required this.progressColor,
    required this.trackColor,
    required this.tickColor,
  });

  final double progress;
  final double min;
  final double max;
  final double trackWidth;
  final double majorTickEvery;
  final double minorTickEvery;
  final Color progressColor;
  final Color trackColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 4;
    final labelR = outerR - 22;
    final tickOuter = labelR - 4;
    final trackR = tickOuter - trackWidth * 1.35;
    final trackRect = Rect.fromCircle(center: center, radius: trackR);

    final span = max - min;
    if (span <= 0) {
      return;
    }

    // Ticks (outer ring).
    final minor = minorTickEvery <= 0 ? 1.0 : minorTickEvery;
    final major = majorTickEvery <= 0 ? 10.0 : majorTickEvery;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final majorTickPaint = Paint()
      ..color = tickColor.withOpacity(0.95)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final steps = ((span) / minor).round();
    final majorStep = math.max(1, (major / minor).round());

    for (var i = 0; i <= steps; i++) {
      final v = min + i * minor;
      final t = ((v - min) / span).clamp(0.0, 1.0);
      final angle = MonitorArcGeometry.angleForProgress(t);
      final onMajor = i % majorStep == 0;

      final inner = onMajor ? tickOuter - 14 : tickOuter - 8;
      final p0 = MonitorArcGeometry.pointOnArc(center, inner, angle);
      final p1 = MonitorArcGeometry.pointOnArc(center, tickOuter, angle);
      canvas.drawLine(p0, p1, onMajor ? majorTickPaint : tickPaint);

      if (onMajor) {
        final labelPos =
            MonitorArcGeometry.pointOnArc(center, labelR + 2, angle);
        final label = v == v.roundToDouble()
            ? v.round().toString()
            : v.toStringAsFixed(0);
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: tickColor,
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }

    // Inner track + progress.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      trackRect,
      MonitorArcGeometry.startAngle,
      MonitorArcGeometry.sweepAngle,
      false,
      trackPaint,
    );

    final t = progress.clamp(0.0, 1.0);
    if (t > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackWidth
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
  }

  @override
  bool shouldRepaint(covariant _CurrentArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.trackWidth != trackWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
