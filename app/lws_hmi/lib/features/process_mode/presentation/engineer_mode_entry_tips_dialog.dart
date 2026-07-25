import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Process-lifetime suppress for the engineer entry tip (not persisted).
///
/// Checking “don’t remind me again” only hides the dialog until the next HMI
/// process start / reboot — never written to `misc-settings.json`.
abstract final class EngineerModeEntryTipGate {
  static bool _suppressedThisBoot = false;

  static bool get isSuppressedThisBoot => _suppressedThisBoot;

  static void suppressForThisBoot() {
    _suppressedThisBoot = true;
  }

  /// Test-only reset.
  @visibleForTesting
  static void resetForTest() {
    _suppressedThisBoot = false;
  }
}

/// lws-ui's first-entry notice shared by Home and Quick → Engineer handoff.
final class EngineerModeEntryTipsResult {
  const EngineerModeEntryTipsResult({required this.dontShowAgain});

  final bool dontShowAgain;
}

Future<EngineerModeEntryTipsResult?> showEngineerModeEntryTipsDialog(
  BuildContext context,
) {
  return showDialog<EngineerModeEntryTipsResult>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (context) => const _EngineerModeEntryTipsDialog(),
  );
}

final class _EngineerModeEntryTipsDialog extends StatefulWidget {
  const _EngineerModeEntryTipsDialog();

  @override
  State<_EngineerModeEntryTipsDialog> createState() =>
      _EngineerModeEntryTipsDialogState();
}

final class _EngineerModeEntryTipsDialogState
    extends State<_EngineerModeEntryTipsDialog> {
  bool _dontShowAgain = true;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      key: const ValueKey('engineer-mode-entry-tips'),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: math.min(700, viewport.width - 48),
        height: math.min(680, viewport.height - 48),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE3121214),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x55FFFFFF)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 34, 36, 28),
            child: Column(
              children: [
                Image.asset(
                  'assets/process/engineer_mode_entry_notice.webp',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 36),
                const Text(
                  'Engineer Mode Notice',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF37535),
                    fontSize: 53,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  height: 148,
                  child: SingleChildScrollView(
                    child: Text(
                      'Engineer Mode unlocks advanced parameter customization '
                      'for experienced users. We recommend learning how the '
                      'machine works before making fine adjustments.',
                      style: TextStyle(
                        color: Color(0xFFE1E1E1),
                        fontSize: 37,
                        height: 1.16,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  key: const ValueKey('engineer-mode-entry-confirm'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    CyberClickSoundRegistry.playClick();
                    Navigator.of(context).pop(
                      EngineerModeEntryTipsResult(
                        dontShowAgain: _dontShowAgain,
                      ),
                    );
                  },
                  child: Ink(
                    width: 500,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF37535), Color(0xFFE85D2A)],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Confirm & Enter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  key: const ValueKey('engineer-mode-entry-dont-show-again'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    CyberClickSoundRegistry.playClick();
                    setState(() => _dontShowAgain = !_dontShowAgain);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IgnorePointer(
                        child: Checkbox(
                          value: _dontShowAgain,
                          onChanged: (_) {},
                          activeColor: const Color(0xFFF37535),
                        ),
                      ),
                      const Text(
                        'Don’t remind me again this boot',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
