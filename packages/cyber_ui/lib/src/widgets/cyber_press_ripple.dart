import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';

/// Simplified press ripple (Frost reversible ripple stand-in).
class CyberPressRipple extends StatelessWidget {
  const CyberPressRipple({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: CyberColors.borderHighlight.withOpacity(0.35),
        highlightColor: CyberColors.lightFillTop,
        child: child,
      ),
    );
  }
}
