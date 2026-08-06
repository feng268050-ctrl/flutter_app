import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Accordion header for the engineer left-panel ramp chart (lws-ui).
final class EngineerRampAccordionHeader extends StatelessWidget {
  const EngineerRampAccordionHeader({
    super.key,
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            key: const ValueKey('engineer-ramp-accordion'),
            onTap: () {
              CyberClickSoundRegistry.playClick();
              onToggle();
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.rampChartLabel ??
                        'Ramp Chart',
                    style: context.hmiTypography.sectionTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Color(0x33FFFFFF), height: 1),
      ],
    );
  }
}

/// Continuous / spot welding power ramp visualization (lws-ui LineChart port).
final class EngineerRampChart extends StatelessWidget {
  const EngineerRampChart({
    super.key,
    required this.processType,
    required this.preset,
    required this.startPower,
    required this.endPower,
  });

  final ProcessType processType;
  final ProcessPreset preset;
  final double startPower;
  final double endPower;

  @override
  Widget build(BuildContext context) {
    final model = processType == ProcessType.spotWelding
        ? _RampChartModel.spot(preset)
        : _RampChartModel.continuous(
            preset,
            startPower: startPower,
            endPower: endPower,
          );
    return CustomPaint(
      key: ValueKey('engineer-ramp-chart-${processType.name}'),
      painter: _RampChartPainter(model: model),
      child: const SizedBox.expand(),
    );
  }
}

final class _RampSegment {
  const _RampSegment({
    required this.x0,
    required this.x1,
    required this.y0,
    required this.y1,
    required this.orange,
  });

  final double x0;
  final double x1;
  final double y0;
  final double y1;
  final bool orange;
}

final class _RampEdge {
  const _RampEdge({
    required this.points,
    required this.orange,
  });

  final List<Offset> points;
  final bool orange;
}

final class _RampAxisLabel {
  const _RampAxisLabel({
    required this.x,
    required this.text,
    required this.color,
  });

  final double x;
  final String text;
  final Color color;
}

final class _RampChartModel {
  const _RampChartModel({
    required this.segments,
    required this.edges,
    required this.maxX,
    required this.maxY,
    this.axisLabels = const [],
  });

  final List<_RampSegment> segments;
  final List<_RampEdge> edges;
  final double maxX;
  final double maxY;
  final List<_RampAxisLabel> axisLabels;

  static double _v(ProcessPreset preset, String key) =>
      preset.parameters.values[key] ?? 0;

  static _RampChartModel continuous(
    ProcessPreset preset, {
    required double startPower,
    required double endPower,
  }) {
    final laser = _v(preset, 'process.laser_power');
    final t1X = _v(preset, 'process.blowing_delay');
    var t2X = _v(preset, 'process.power_ramp_up_duration');
    final plateau = (t1X * 2 + t2X * 2) / 4;
    t2X += t1X;
    final t3X = t2X + plateau;
    var t4X = _v(preset, 'process.power_ramp_down_duration');
    t4X += t3X;
    var t5X = _v(preset, 'process.gas_off_delay');
    t5X += t4X;

    final t1Y = startPower;
    final t2Y = laser;
    final t3Y = laser;
    final t4Y = endPower;

    return _RampChartModel(
      segments: [
        _RampSegment(x0: 0, x1: t1X, y0: t1Y, y1: t1Y, orange: false),
        _RampSegment(x0: t1X, x1: t2X, y0: t1Y, y1: t2Y, orange: true),
        _RampSegment(x0: t2X, x1: t3X, y0: t2Y, y1: t3Y, orange: true),
        _RampSegment(x0: t3X, x1: t4X, y0: t3Y, y1: t4Y, orange: true),
        _RampSegment(x0: t4X, x1: t5X, y0: t4Y, y1: t4Y, orange: false),
      ],
      edges: [
        _RampEdge(
          points: [Offset(0, t1Y), Offset(t1X, t1Y)],
          orange: false,
        ),
        _RampEdge(
          points: [
            Offset(t1X, t1Y),
            Offset(t2X, t2Y),
            Offset(t3X, t3Y),
            Offset(t4X, t4Y),
          ],
          orange: true,
        ),
        _RampEdge(
          points: [Offset(t4X, t4Y), Offset(t5X, t4Y)],
          orange: false,
        ),
      ],
      maxX: t5X + 3,
      maxY: math.max(t1Y, t2Y) + 2,
      axisLabels: [
        _RampAxisLabel(x: t1X, text: 'T1', color: const Color(0xFF324BF3)),
        _RampAxisLabel(x: t2X, text: 'T2', color: const Color(0xFFFFC266)),
        _RampAxisLabel(x: t4X, text: 'T3', color: const Color(0xFFFD7632)),
        _RampAxisLabel(x: t5X, text: 'T4', color: const Color(0xFF324BF3)),
      ],
    );
  }

  static _RampChartModel spot(ProcessPreset preset) {
    final interval = _v(preset, 'process.spot_welding_interval');
    final duration = _v(preset, 'process.spot_welding_duration');
    final laser = _v(preset, 'process.laser_power');
    final t1 = interval;
    final t2 = t1 + duration;
    final t3 = t2 + interval;
    final t4 = t3 + duration;
    final t5 = t4 + interval;
    final t6 = t5 + duration;
    const low = 0.05;

    return _RampChartModel(
      segments: [
        _RampSegment(x0: 0, x1: t1, y0: laser, y1: laser, orange: false),
        _RampSegment(x0: t1, x1: t2, y0: laser, y1: laser, orange: true),
        _RampSegment(x0: t2, x1: t3, y0: laser, y1: laser, orange: false),
        _RampSegment(x0: t3, x1: t4, y0: laser, y1: laser, orange: true),
        _RampSegment(x0: t4, x1: t5, y0: laser, y1: laser, orange: false),
        _RampSegment(x0: t5, x1: t6, y0: laser, y1: laser, orange: true),
      ],
      edges: [
        _RampEdge(
            points: [const Offset(0, low), Offset(t1, low)], orange: false),
        _RampEdge(points: [Offset(t1, laser), Offset(t2, laser)], orange: true),
        _RampEdge(points: [Offset(t2, low), Offset(t3, low)], orange: false),
        _RampEdge(points: [Offset(t3, laser), Offset(t4, laser)], orange: true),
        _RampEdge(points: [Offset(t4, low), Offset(t5, low)], orange: false),
        _RampEdge(points: [Offset(t5, laser), Offset(t6, laser)], orange: true),
      ],
      maxX: t6 + 3,
      maxY: laser + 2,
      axisLabels: [
        _RampAxisLabel(x: t1, text: 'T1', color: const Color(0xFF324BF3)),
        _RampAxisLabel(x: t2, text: 'T2', color: const Color(0xFFFD7632)),
      ],
    );
  }
}

final class _RampChartPainter extends CustomPainter {
  _RampChartPainter({required this.model});

  final _RampChartModel model;

  static const _blue = Color(0xFF0F0AFF);
  static const _orange = Color(0xFFFFC266);
  /// Ladder micro (12) — axis tick labels on CustomPainter.
  static const _axisLabelSize = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 28.0;
    const padR = 16.0;
    const padT = 24.0;
    const padB = 28.0;
    final plot =
        Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);
    if (plot.width <= 1 || plot.height <= 1) {
      return;
    }

    final maxX = model.maxX <= 0 ? 1.0 : model.maxX;
    final maxY = model.maxY <= 0 ? 1.0 : model.maxY;

    Offset map(double x, double y) {
      final nx = (x / maxX).clamp(0.0, 1.0);
      final ny = (y / maxY).clamp(0.0, 1.0);
      return Offset(
        plot.left + nx * plot.width,
        plot.bottom - ny * plot.height,
      );
    }

    final axisPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);

    for (final label in model.axisLabels) {
      if (label.x <= 0) {
        continue;
      }
      final anchor = map(label.x, 0);
      final tp = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: label.color,
            fontSize: _axisLabelSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(anchor.dx - tp.width / 2, plot.bottom + 2),
      );
    }

    for (final seg in model.segments) {
      final p0 = map(seg.x0, seg.y0);
      final p1 = map(seg.x1, seg.y1);
      final p2 = map(seg.x1, 0);
      final p3 = map(seg.x0, 0);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      final shader = ui.Gradient.linear(
        Offset(p0.dx, plot.top),
        Offset(p0.dx, plot.bottom),
        seg.orange
            ? const [
                Color(0xFFFF5520),
                Color(0xE6FF7A30),
                Color(0x1AFFB8B8),
              ]
            : const [
                Color(0xE60F0AFF),
                Color(0x990F0AFF),
                Color(0x260F0AFF),
              ],
        const [0.0, 0.4, 1.0],
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.fill,
      );
    }

    for (final edge in model.edges) {
      if (edge.points.length < 2) {
        continue;
      }
      final first = map(edge.points.first.dx, edge.points.first.dy);
      final path = Path()..moveTo(first.dx, first.dy);
      for (var i = 1; i < edge.points.length; i++) {
        final p = map(edge.points[i].dx, edge.points[i].dy);
        path.lineTo(p.dx, p.dy);
      }
      final color = edge.orange ? _orange : _blue;
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RampChartPainter oldDelegate) => true;
}
