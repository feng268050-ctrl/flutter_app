import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_press_feedback.dart';
import 'package:cyber_ui/src/widgets/cyber_press_ink_splash.dart';
import 'package:flutter/material.dart';

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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: reduceMotion
            ? CyberPressFeedback.overlay
            : CyberColors.borderHighlight.withOpacity(0.35),
        highlightColor:
            reduceMotion ? Colors.transparent : CyberColors.lightFillTop,
        splashFactory: reduceMotion
            ? CyberPressInkSplash.splashFactory
            : InkSplash.splashFactory,
        child: child,
      ),
    );
  }
}
