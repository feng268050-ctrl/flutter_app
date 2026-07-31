import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// App-local FrostCard parity for Engineer Mode content panels.
///
/// Solid 1px bright edge (no frost gradient). [edge] is retained for call-site
/// compatibility but ignored.
enum EngineerFrostEdge { topLeftBottomRight, bottomLeftTopRight }

final class EngineerFrostPanel extends StatelessWidget {
  const EngineerFrostPanel({
    super.key,
    required this.child,
    required this.edge,
  });

  final Widget child;
  final EngineerFrostEdge edge;

  /// Shared solid bright-edge stroke across Engineer / Monitor panels.
  static const edgeWidth = 1.0;
  static const edgeColor = CyberColors.borderUniform;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return CyberCard(
      // Static capture — realtime BackdropFilter on two large panels made
      // Engineer tab switches hitch on the board.
      sampleMode: CyberBlurSampleMode.firstFrame,
      intensity: CyberBlurIntensity.low,
      blurTint: CyberBlurTint.dark,
      borderRadius: radius,
      outlineStyle: CyberPanelOutlineStyle.uniform,
      borderWidth: edgeWidth,
      borderColor: edgeColor,
      child: child,
    );
  }
}
