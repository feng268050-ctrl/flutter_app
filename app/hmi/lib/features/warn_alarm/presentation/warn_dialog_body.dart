import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Warn dialog body matching lws-ui `dialog_frost_body_prompt` + confirm action.
///
/// Layout: centered alarm icon → title → dark body → orange Confirm.
/// [infoStyle] uses black title (lws-ui INFO_TYPE); otherwise red WARN title.
class WarnDialogBody extends StatelessWidget {
  const WarnDialogBody({
    super.key,
    required this.title,
    required this.body,
    required this.onConfirm,
    this.beforeConfirm,
    this.confirmLabel = 'Confirm',
    this.infoStyle = false,
  });

  /// Product alarm title (e.g. "Camera Communication Alarm").
  final String title;

  /// Instruction / detail copy.
  final String body;

  final String confirmLabel;
  final VoidCallback onConfirm;

  /// Stop warn loop before click (single mpg123 session — mutual exclusion).
  final Future<void> Function()? beforeConfirm;

  /// When true, title is black (dangerous-ops bypass INFO).
  final bool infoStyle;

  static const iconAsset = 'assets/warn/alarm_warn_icon.webp';

  /// Bright warn red (lws-ui WARN_TYPE title).
  static const titleRed = Color(0xFFFF0000);

  /// INFO title (lws-ui INFO_TYPE).
  static const titleBlack = Color(0xFF000000);

  /// Body on light frost (lws-ui `text_black`).
  static const bodyDark = Color(0xFF1A1A1A);

  static const iconSize = 120.0;
  static const titleSize = 32.0;
  static const bodySize = 20.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              iconAsset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: infoStyle ? titleBlack : titleRed,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Text(
                body,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  color: bodyDark,
                  fontSize: bodySize,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              child: SizedBox(
                width: double.infinity,
                height: CyberDimens.actionButtonHeight,
                child: _WarnConfirmButton(
                  label: confirmLabel,
                  beforeConfirm: beforeConfirm,
                  onPressed: onConfirm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped orange confirm (screenshot / FrostPromptConfirmButton).
class _WarnConfirmButton extends StatelessWidget {
  const _WarnConfirmButton({
    required this.label,
    required this.onPressed,
    this.beforeConfirm,
  });

  final String label;
  final VoidCallback onPressed;
  final Future<void> Function()? beforeConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          unawaited(() async {
            // Release warn loop first so click can use the sticky mpg123 session.
            await beforeConfirm?.call();
            CyberClickSoundRegistry.playClick();
            onPressed();
          }());
        },
        borderRadius: BorderRadius.circular(CyberDimens.actionButtonHeight / 2),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(CyberDimens.actionButtonHeight / 2),
            border: Border.all(
              color: CyberColors.buttonPrimaryAccent,
              width: CyberDimens.buttonStrokeWidth,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xE6FF9A5C),
                Color(0xD9FF8A4D),
                Color(0xCCFF7A3D),
              ],
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
