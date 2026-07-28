import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// App-local FrostCard parity for Engineer Mode content panels.
///
/// lws-ui uses a dark baseline stroke plus two localized highlights on the
/// selected diagonal. [CyberCard] supplies the backdrop blur; this foreground
/// painter recreates its visible bright edges using Flutter canvas shaders.
enum EngineerFrostEdge { topLeftBottomRight, bottomLeftTopRight }

final class EngineerFrostPanel extends StatelessWidget {
  const EngineerFrostPanel({
    super.key,
    required this.child,
    required this.edge,
  });

  final Widget child;
  final EngineerFrostEdge edge;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return CustomPaint(
      foregroundPainter: _EngineerFrostBorderPainter(edge: edge),
      child: CyberCard(
        // Static capture — realtime BackdropFilter on two large panels made
        // Engineer tab switches hitch on the board.
        sampleMode: CyberBlurSampleMode.firstFrame,
        intensity: CyberBlurIntensity.low,
        blurTint: CyberBlurTint.dark,
        borderRadius: radius,
        // FrostCard's baseline is deliberately dark; the painter above adds
        // the two localized highlights from lws-ui's PanelBorderPainter.
        borderColor: const Color(0x66000000),
        child: child,
      ),
    );
  }
}

final class _EngineerFrostBorderPainter extends CustomPainter {
  const _EngineerFrostBorderPainter({required this.edge});

  final EngineerFrostEdge edge;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    final rect = Offset.zero & size;
    final strokeRect = rect.deflate(strokeWidth / 2);
    final border = RRect.fromRectAndRadius(
      strokeRect,
      const Radius.circular(16 - strokeWidth / 2),
    );
    final start = edge == EngineerFrostEdge.topLeftBottomRight
        ? Alignment.topLeft
        : Alignment.bottomLeft;
    final end = edge == EngineerFrostEdge.topLeftBottomRight
        ? Alignment.bottomRight
        : Alignment.topRight;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: start,
        end: end,
        colors: const [
          Color(0x77FFFFFF),
          Color(0x8868686C),
          Color(0x66000000),
          Color(0x8868686C),
          Color(0x77FFFFFF),
        ],
        stops: const [0, 0.20, 0.5, 0.80, 1],
      ).createShader(rect);
    canvas.drawRRect(border, paint);
  }

  @override
  bool shouldRepaint(_EngineerFrostBorderPainter oldDelegate) =>
      oldDelegate.edge != edge;
}
