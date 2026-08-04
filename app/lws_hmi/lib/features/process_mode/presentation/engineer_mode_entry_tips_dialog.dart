import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
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

/// Engineer entry tip — lws-ui `FrostTone.LIGHT` + prompt metrics
/// (`engineer_mode_entry_dialog_*` / `frost_dialog_prompt_*`).
Future<EngineerModeEntryTipsResult?> showEngineerModeEntryTipsDialog(
  BuildContext context,
) {
  final width = _EngineerModeEntryTipsBodyState.resolveCardWidth(context);
  return TipDialogHost.showLightPrompt<EngineerModeEntryTipsResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Engineer mode entry tips',
    // Width: 600dp floor (title-based grow). Height: 400–600.
    constraints: BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: 400,
      maxHeight: 600,
    ),
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

  /// `engineer_mode_entry_icon_size` / `frost_dialog_prompt_icon_size`.
  static const _iconSize = 150.0;

  /// `frost_dialog_prompt_title_text_size` → [AppTypography.criticalTitle].
  static const _titleSize = AppTypography.criticalTitleSize;

  /// `dialog_frost_body_prompt` content → [AppTypography.largeDialogTitle].
  static const _bodySize = AppTypography.largeDialogTitleSize;

  /// `frost_dialog_prompt_content_inset` / `engineer_mode_entry_dialog_content_padding`.
  static const _contentInset = 36.0;

  /// `engineer_mode_entry_confirm_button_width`.
  static const _confirmMinWidth = 500.0;

  /// `frost_dialog_prompt_dont_show_again_inset`.
  static const _dontShowAgainInset = 14.0;

  /// Engineer entry dialog width floor.
  static const _minCardWidth = 600.0;

  /// `WarnDialogUtil.WARN_DIALOG_MAX_WIDTH_FRACTION`.
  static const _maxWidthFraction = 0.95;

  static const _title = 'Engineer Mode Notice';

  static const _body =
      'Engineer Mode unlocks advanced parameter customization '
      'for experienced users. We recommend learning how the '
      'machine works before making fine adjustments.';

  static const _bodyDark = Color(0xFF1A1A1A);
  static const _labelMuted = Color(0x80222222);
  static const _titleOrange = Color(0xFFF37535);
  static const _checkboxGreen = Color(0xFF34C759);

  /// Mirrors lws-ui `FrostPromptDialog.resolveTitleBasedWidthPx`.
  static double resolveCardWidth(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = math.max(_minCardWidth, screenW * _maxWidthFraction);
    final painter = TextPainter(
      text: const TextSpan(
        text: _title,
        style: TextStyle(
          fontSize: _titleSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return (painter.width + _contentInset * 2).clamp(_minCardWidth, maxW);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Body/action XMLs add horizontal content inset on top of shell padding.
      padding: const EdgeInsets.symmetric(horizontal: _contentInset),
      child: Column(
        key: const ValueKey('engineer-mode-entry-tips'),
        mainAxisSize: MainAxisSize.max,
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
          const SizedBox(height: _contentInset),
          // Card width follows the title; FittedBox is a safety net for
          // locales / text scale that still overflow the 95% screen cap.
          const SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _title,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: _titleOrange,
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: _contentInset),
          // Use remaining card height (not Android's 148dp scroll cap). That
          // fixed maxHeight clipped mid-line and looked like a white mask
          // above Confirm while empty space sat below.
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _body,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  color: _bodyDark,
                  fontSize: _bodySize,
                  fontWeight: FontWeight.w400,
                  // Android `lineSpacingExtra` 6dp on 37sp.
                  height: (_bodySize + 6) / _bodySize,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          // Light overlay action section `layout_marginTop` 12dp.
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _confirmMinWidth,
                maxWidth: _confirmMinWidth,
              ),
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
                  child: Text(
                    'Confirm & Enter',
                    style: AppTypography.pageTitle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _dontShowAgainInset),
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
                          side: const BorderSide(
                            color: _labelMuted,
                            width: 1.5,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Don’t show again this session',
                    style: TextStyle(
                      color: _labelMuted,
                      fontSize: AppTypography.sectionTitleSize,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
