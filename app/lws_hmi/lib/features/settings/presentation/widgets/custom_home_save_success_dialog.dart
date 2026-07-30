import 'dart:ui';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Save result dialog matching lws-ui Custom Home's dark success tip.
///
/// This intentionally has its own orange pill action: the global primary
/// button is blue in the product theme, while the original Custom Home action
/// is orange.
Future<void> showCustomHomeSaveSuccessDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Save succeeded',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The reference tip dims and softens the whole Custom Home editor.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: const ColoredBox(color: Color(0xB8070818)),
            ),
          ),
          FadeTransition(
            opacity: animation,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.62,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 520,
                    maxWidth: 960,
                  ),
                  child: const _CustomHomeSaveSuccessDialogBody(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _CustomHomeSaveSuccessDialogBody extends StatelessWidget {
  const _CustomHomeSaveSuccessDialogBody();

  static const _dialogRadius = 26.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_dialogRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_dialogRadius),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xEE303653), Color(0xEB15172B)],
            ),
            border: Border.all(color: const Color(0xB4B4B9D2), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 28),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Save Succeeded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 56),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00F112),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF102239),
                    size: 66,
                    weight: 700,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Done',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE6E7ED),
                    fontSize: 38,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 52),
                _OrangePillButton(
                  label: 'OK',
                  onPressed: () {
                    CyberClickSoundRegistry.playClick();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _OrangePillButton extends StatelessWidget {
  const _OrangePillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('custom-home-save-success-ok'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 104,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF853E), Color(0xFFFF5C09)],
            ),
            border: Border.all(color: const Color(0xFFFFB070), width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x66FF5C09), blurRadius: 12),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
