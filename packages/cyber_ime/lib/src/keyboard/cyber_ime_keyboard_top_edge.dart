import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Top hairline on the keyboard frost band: bright center, fades to both ends
/// (两边向中间渐变亮边). Not painted on keycaps.
class CyberImeKeyboardTopEdge extends StatelessWidget {
  const CyberImeKeyboardTopEdge({
    super.key,
    this.height = 1,
  });

  final double height;

  /// Horizontal H–center–H gradient (transparent → bright → transparent).
  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0x00FFFFFF),
      CyberColors.lightBorderHighlight,
      Color(0x00FFFFFF),
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
