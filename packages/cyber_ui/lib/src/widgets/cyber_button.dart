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
    this.expand = false,
    this.foregroundColor,
    this.onLongPress,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final CyberButtonVariant variant;
  final CyberButtonSize size;
  final bool clickSoundEnabled;

  /// When true, fill parent constraints (IME keycaps) instead of fixed height.
  final bool expand;

  /// Optional label/icon color override (e.g. IME accent backspace).
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final height = size == CyberButtonSize.small
        ? CyberDimens.actionButtonSmallHeight
        : CyberDimens.actionButtonHeight;
    final hPad = expand
        ? 0.0
        : (size == CyberButtonSize.small
            ? CyberDimens.actionButtonSmallPaddingHorizontal
            : CyberDimens.actionButtonPaddingHorizontal);
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
    final textColor = foregroundColor ?? fg;

    void handleTap() {
      if (onPressed == null) return;
      if (clickSoundEnabled) {
        CyberClickSoundRegistry.playClick();
      }
      onPressed!();
    }

    final ink = Ink(
      height: expand ? null : height,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      decoration: BoxDecoration(
        color: variant == CyberButtonVariant.secondary ? bg : null,
        borderRadius: radius,
        border: Border.all(
          color: border,
          width: CyberDimens.buttonStrokeWidth,
        ),
        gradient: variant == CyberButtonVariant.primary
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE6FF9A5C),
                  Color(0xD9FF8A4D),
                  Color(0xCCFF7A3D),
                ],
              )
            : variant == CyberButtonVariant.light
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CyberColors.lightFillTop,
                      CyberColors.lightFillMid,
                      CyberColors.lightFillBottom,
                    ],
                  )
                : null,
      ),
      child: Center(
        child: DefaultTextStyle(
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          child: IconTheme(
            data: IconThemeData(color: textColor, size: expand ? 22 : 20),
            child: child,
          ),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed == null ? null : handleTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: expand ? SizedBox.expand(child: ink) : ink,
      ),
    );
  }
}
