import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';
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

/// Engineer entry tip — lws-ui `FrostTone.LIGHT` cream glass (full-page
/// baked Gaussian + 透视) + prompt metrics (`engineer_mode_entry_dialog_*` /
/// `frost_dialog_prompt_*`).
Future<EngineerModeEntryTipsResult?> showEngineerModeEntryTipsDialog(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context)!;
  final width = _EngineerModeEntryTipsBodyState.resolveCardWidth(
    context,
    l10n.engineerModeEntryTitle,
  );
  // Former max was 600; grow by half the leftover vertical slack so top/bottom
  // screen margins each shrink by half: (screenH + 600) / 2.
  final screenH = MediaQuery.sizeOf(context).height;
  final cardH = (screenH + 600) / 2;
  return TipDialogHost.showLightPrompt<EngineerModeEntryTipsResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Engineer mode entry tips',
    // Width: 600dp floor (title-based grow). Height tight to halved margins.
    constraints: BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: cardH,
      maxHeight: cardH,
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
  bool _dontShowAgain = false;

  /// `engineer_mode_entry_icon_size` / `frost_dialog_prompt_icon_size`.
  /// Slightly under Android 150 so body lines clear the scroll clip after
  /// TipFrostDivider chrome was added.
  static const _iconSize = 140.0;

  /// `frost_dialog_prompt_title_text_size` → [HmiTypography.tipPromptTitleSize].
  static const _titleSize = HmiTypography.tipPromptTitleSize;

  /// `dialog_frost_body_prompt` content → [HmiTypography.tipPromptBodySize].
  static const _bodySize = HmiTypography.tipPromptBodySize;

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

  static const _bodyDark = Color(0xFF1A1A1A);
  static const _labelMuted = Color(0x80222222);
  static const _titleOrange = Color(0xFFF37535);

  /// Mirrors lws-ui `FrostPromptDialog.resolveTitleBasedWidthPx`.
  static double resolveCardWidth(BuildContext context, String title) {
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = math.max(_minCardWidth, screenW * _maxWidthFraction);
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
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
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = context.hmiTypography.engineerTipTitle.copyWith(
      color: _titleOrange,
      fontWeight: FontWeight.w700,
      height: 1.0,
      decoration: TextDecoration.none,
    );
    final bodyBase = context.hmiTypography.engineerTipBody;
    final bodySize = bodyBase.fontSize ?? _bodySize;
    final bodyStyle = bodyBase.copyWith(
      color: _bodyDark,
      fontWeight: FontWeight.w400,
      height: (bodySize + 6) / bodySize,
      decoration: TextDecoration.none,
    );
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
          const SizedBox(height: 16),
          // Card width follows the title; FittedBox is a safety net for
          // locales / text scale that still overflow the 95% screen cap.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.engineerModeEntryTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: titleStyle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TipFrostDivider(),
          const SizedBox(height: 16),
          // Remaining height for body. Bottom pad keeps the last line (and
          // descenders) clear of the scroll clip edge above the divider.
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bodySize * 0.35),
              child: WordBoundaryBody(
                text: l10n.engineerModeEntryBody,
                style: bodyStyle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TipFrostDivider(),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _confirmMinWidth,
                maxWidth: _confirmMinWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                height: HmiButtonMetrics.heroHeight,
                child: CyberButton(
                  key: const ValueKey('engineer-mode-entry-confirm'),
                  onPressed: () {
                    Navigator.of(context).pop(
                      EngineerModeEntryTipsResult(
                        dontShowAgain: _dontShowAgain,
                      ),
                    );
                  },
                  variant: CyberButtonVariant.primary,
                  shape: CyberButtonShape.rounded,
                  size: CyberButtonSize.large,
                  height: HmiButtonMetrics.heroHeight,
                  stretch: true,
                  child: Text(
                    l10n.engineerModeEntryConfirm,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: HmiTypography.dialogConfirmLabelSize,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _dontShowAgainInset),
          Center(
            child: CyberCheckbox(
              key: const ValueKey('engineer-mode-entry-dont-show-again'),
              value: _dontShowAgain,
              size: CyberDimens.checkboxLargeSize,
              onChanged: (v) {
                setState(() => _dontShowAgain = v ?? false);
              },
              label: Text(
                l10n.dontShowAgainThisSession,
                style: context.hmiTypography.dialogOptionLabel.copyWith(
                  height: 1.0,
                  color: _labelMuted,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
