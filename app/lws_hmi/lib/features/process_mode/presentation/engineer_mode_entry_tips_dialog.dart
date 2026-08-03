import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

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

/// Engineer entry tip — lws-ui `FrostTone.LIGHT` cream frost (`dialog_frost_light_overlay`).
Future<EngineerModeEntryTipsResult?> showEngineerModeEntryTipsDialog(
  BuildContext context,
) {
  return TipDialogHost.showLightPrompt<EngineerModeEntryTipsResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Engineer mode entry tips',
    constraints: const BoxConstraints(maxWidth: 700, maxHeight: 640),
    builder: (dialogContext) => const _EngineerModeEntryTipsBody(),
  );
}

final class _EngineerModeEntryTipsBody extends StatefulWidget {
  const _EngineerModeEntryTipsBody();

  @override
  State<_EngineerModeEntryTipsBody> createState() =>
      _EngineerModeEntryTipsBodyState();
}

final class _EngineerModeEntryTipsBodyState
    extends State<_EngineerModeEntryTipsBody> {
  bool _dontShowAgain = true;

  static const _iconSize = 120.0;
  static const _titleSize = 32.0;
  static const _bodySize = 20.0;
  static const _bodyDark = Color(0xFF1A1A1A);
  static const _labelMuted = Color(0x80222222);
  static const _titleOrange = Color(0xFFF37535);
  static const _checkboxGreen = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('engineer-mode-entry-tips'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/process/engineer_mode_entry_notice.webp',
            width: _iconSize,
            height: _iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Engineer Mode Notice',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _titleOrange,
            fontSize: _titleSize,
            fontWeight: FontWeight.w700,
            height: 1.15,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: CyberDimens.contentPadding),
        const TipFrostDivider(),
        const SizedBox(height: CyberDimens.contentPadding),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: const SingleChildScrollView(
            child: Text(
              'Engineer Mode unlocks advanced parameter customization '
              'for experienced users. We recommend learning how the '
              'machine works before making fine adjustments.',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: _bodyDark,
                fontSize: _bodySize,
                fontWeight: FontWeight.w400,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: CyberDimens.contentPadding),
        const TipFrostDivider(),
        const SizedBox(height: CyberDimens.contentPadding),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 500),
            child: SizedBox(
              width: double.infinity,
              child: CyberButton(
                key: const ValueKey('engineer-mode-entry-confirm'),
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                stretch: true,
                height: CyberDimens.actionButtonHeight,
                onPressed: () {
                  Navigator.of(context).pop(
                    EngineerModeEntryTipsResult(
                      dontShowAgain: _dontShowAgain,
                    ),
                  );
                },
                child: const Text('Confirm & Enter'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: InkWell(
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
                  child: SizedBox(
                    width: CyberDimens.checkboxLargeSize,
                    height: CyberDimens.checkboxLargeSize,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Checkbox(
                        value: _dontShowAgain,
                        activeColor: _checkboxGreen,
                        checkColor: Colors.white,
                        side: const BorderSide(color: _labelMuted, width: 1.5),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Don’t show again this session',
                  style: TextStyle(
                    color: _labelMuted,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
