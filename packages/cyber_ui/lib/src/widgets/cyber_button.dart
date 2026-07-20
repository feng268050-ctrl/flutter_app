import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';

/// Thin Material button that plays [CyberClickSoundRegistry] on press.
class CyberButton extends StatelessWidget {
  const CyberButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.clickSoundEnabled = true,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool clickSoundEnabled;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: style,
      onPressed: onPressed == null
          ? null
          : () {
              if (clickSoundEnabled) {
                CyberClickSoundRegistry.playClick();
              }
              onPressed!();
            },
      child: child,
    );
  }
}
