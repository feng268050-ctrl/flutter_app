import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';

enum CyberButtonVariant { primary, secondary, light }

enum CyberButtonSize { regular, small }

/// Frost-styled button with click-sound hook (lws-ui `FrostButton` stand-in).
class CyberButton extends StatelessWidget {
  const CyberButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = CyberButtonVariant.primary,
    this.size = CyberButtonSize.regular,
    this.clickSoundEnabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final CyberButtonVariant variant;
  final CyberButtonSize size;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    final height = size == CyberButtonSize.small
        ? CyberDimens.actionButtonSmallHeight
        : CyberDimens.actionButtonHeight;
    final hPad = size == CyberButtonSize.small
        ? CyberDimens.actionButtonSmallPaddingHorizontal
        : CyberDimens.actionButtonPaddingHorizontal;
    final radius = BorderRadius.circular(CyberDimens.rectangleButtonCornerRadius);

    final (bg, fg, border) = switch (variant) {
      CyberButtonVariant.primary => (
          CyberColors.buttonPrimaryAccent.withOpacity(0.85),
          CyberColors.textPrimary,
          CyberColors.buttonPrimaryAccent,
        ),
      CyberButtonVariant.secondary => (
          CyberColors.fillMid,
          CyberColors.buttonSecondaryText,
          CyberColors.borderMid,
        ),
      CyberButtonVariant.light => (
          CyberColors.lightFillMid,
          CyberColors.textPrimary,
          CyberColors.lightBorderHighlight,
        ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                if (clickSoundEnabled) {
                  CyberClickSoundRegistry.playClick();
                }
                onPressed!();
              },
        borderRadius: radius,
        child: Ink(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(
              color: border,
              width: CyberDimens.buttonStrokeWidth,
            ),
          ),
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
