import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Confirm leaving CNC running mode (lws-ui `CNCExitDialog`).
Future<bool> showCncExitDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 120),
        child: DecoratedBox(
          key: const ValueKey('quick-mode-cnc-exit-dialog'),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0741BA), width: 8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(106, 56, 106, 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.exitCncModeConfirmTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.sectionTitleSize,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 56),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CncDialogButton(
                      key: const ValueKey('quick-mode-cnc-exit-confirm'),
                      label: l10n.confirmText,
                      onPressed: () => Navigator.pop(dialogContext, true),
                    ),
                    const SizedBox(width: 42),
                    _CncDialogButton(
                      key: const ValueKey('quick-mode-cnc-exit-cancel'),
                      label: l10n.cancelText,
                      onPressed: () => Navigator.pop(dialogContext, false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

final class _CncDialogButton extends StatelessWidget {
  const _CncDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 160,
        height: CyberDimens.actionButtonSmallHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(ProcessModeAssets.cncDialogBtn),
              fit: BoxFit.fill,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTypography.controlSize,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
