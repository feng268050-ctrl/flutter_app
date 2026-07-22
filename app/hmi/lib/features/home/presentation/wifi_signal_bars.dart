import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Classic status-bar Wi‑Fi arcs (1–4 bars). Level 0 = empty outline.
class WifiSignalBars extends StatelessWidget {
  const WifiSignalBars({
    super.key,
    required this.level,
    required this.size,
    required this.color,
    this.emptyColor,
  });

  /// 0 = idle/empty, 1–4 = signal strength.
  final int level;
  final double size;
  final Color color;
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WifiBarsPainter(
        level: level.clamp(0, 4),
        color: color,
        emptyColor: emptyColor ?? color.withOpacity(0.28),
      ),
    );
  }
}

/// Connecting animation: cycles filled bars 1 → 2 → 3 → 4 → 1.
class WifiSignalBarsConnecting extends StatefulWidget {
  const WifiSignalBarsConnecting({
    super.key,
    required this.size,
    required this.color,
    this.period = const Duration(milliseconds: 900),
  });

  final double size;
  final Color color;
  final Duration period;

  @override
  State<WifiSignalBarsConnecting> createState() =>
      _WifiSignalBarsConnectingState();
}

class _WifiSignalBarsConnectingState extends State<WifiSignalBarsConnecting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void didUpdateWidget(covariant WifiSignalBarsConnecting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _ctrl.duration = widget.period;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // 4 discrete frames: levels 1,2,3,4.
        final frame = (_ctrl.value * 4).floor().clamp(0, 3);
        return WifiSignalBars(
          level: frame + 1,
          size: widget.size,
          color: widget.color,
        );
      },
    );
  }
}

class _WifiBarsPainter extends CustomPainter {
  _WifiBarsPainter({
    required this.level,
    required this.color,
    required this.emptyColor,
  });

  final int level;
  final Color color;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.shortestSide * 0.10).clamp(2.0, 4.0);
    final cx = size.width / 2;
    // Leave padding so painted arcs match Material icon optical size.
    final cy = size.height * 0.78;
    final maxR = size.shortestSide * 0.62;

    final filled = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final empty = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Dot (always filled when level > 0; dim when idle).
    final hub = Paint()..color = level > 0 ? color : emptyColor;
    canvas.drawCircle(Offset(cx, cy), stroke * 0.55, hub);

    // Three arcs above the hub → 4 visual “bars” with the hub.
    const start = -math.pi * 0.75; // ~225°
    const sweep = math.pi * 0.5; // 90° fan
    for (var i = 1; i <= 3; i++) {
      final r = maxR * (i / 3.0);
      final paint = level > i ? filled : empty;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WifiBarsPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.color != color ||
        oldDelegate.emptyColor != emptyColor;
  }
}
