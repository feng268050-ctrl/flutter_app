import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Top hairline on the keyboard frost band: bright at both ends, fades toward
/// center (两边向中间渐变亮边). Not painted on keycaps.
class CyberImeKeyboardTopEdge extends StatelessWidget {
  const CyberImeKeyboardTopEdge({
    super.key,
    this.height = 1,
  });

  final double height;

  /// Horizontal edge–center–edge gradient (bright → transparent → bright).
  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      CyberColors.lightBorderHighlight,
      Color(0x00FFFFFF),
      CyberColors.lightBorderHighlight,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }
}
