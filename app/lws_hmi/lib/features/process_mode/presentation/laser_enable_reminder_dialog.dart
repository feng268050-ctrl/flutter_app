import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart'
    hide MaterialType;
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Result of the laser-enable Important Reminder dialog.
final class LaserEnableReminderResult {
  const LaserEnableReminderResult({required this.dontShowAgain});

  final bool dontShowAgain;
}

/// Shows lws-ui `ReminderExactBuilder` Important Reminder, or returns
/// immediately when [LaserEnableReminderGate] is suppressed for [session].
///
/// Chrome: lws-ui `FrostTone.LIGHT` cream frost (`dialog_frost_light_overlay`).
Future<LaserEnableReminderResult?> showLaserEnableReminderDialog({
  required BuildContext context,
  required ProcessType processType,
  required LaserEnableReminderSession session,
  int focusScaleRef = 0,
}) async {
  if (LaserEnableReminderGate.isSuppressed(session)) {
    return const LaserEnableReminderResult(dontShowAgain: false);
  }
  final screenW = MediaQuery.sizeOf(context).width;
  return TipDialogHost.showLightPrompt<LaserEnableReminderResult>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Laser enable reminder',
    // Tighter vertical pad + taller max so 3-line tip copy under icons fits.
    padding: const EdgeInsets.symmetric(vertical: 12),
    constraints: BoxConstraints(
      maxWidth: (screenW * 0.9).clamp(560.0, 1200.0),
      maxHeight: 800,
    ),
    builder: (dialogContext) => _LaserEnableReminderBody(
      processType: processType,
      focusScaleRef: focusScaleRef,
    ),
  );
}

final class _LaserEnableReminderBody extends StatefulWidget {
  const _LaserEnableReminderBody({
    required this.processType,
    required this.focusScaleRef,
  });

  final ProcessType processType;
  final int focusScaleRef;

  @override
  State<_LaserEnableReminderBody> createState() =>
      _LaserEnableReminderBodyState();
}

final class _LaserEnableReminderBodyState
    extends State<_LaserEnableReminderBody> {
  bool _dontShowAgain = false;

  static const _titleDark = Color(0xFF1A1A1A);
  static const _labelMuted = Color(0x80222222);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showFocus =
        LaserEnableReminderCopy.showsFocusScale(widget.processType);
    final focusAsset =
        ProcessModeAssets.laserReminderFocusScale(widget.focusScaleRef);

    return Column(
      key: const ValueKey('laser-enable-reminder'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.laserEnableReminderTitle,
          textAlign: TextAlign.center,
          style: context.hmiTypography.reminderTitle.copyWith(
            color: _titleDark,
            fontWeight: FontWeight.w700,
            height: 1.1,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 16),
        const TipFrostDivider(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ReminderCard(
                asset: ProcessModeAssets.laserReminderProtection,
                tip: l10n.laserEnableReminderPpe,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReminderCard(
                asset: LaserEnableReminderCopy.nozzleAsset(widget.processType),
                tip: LaserEnableReminderCopy.nozzleTip(
                  widget.processType,
                  l10n,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReminderCard(
                asset: showFocus && focusAsset.isNotEmpty ? focusAsset : null,
                tip: showFocus ? l10n.laserEnableReminderFocus : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const TipFrostDivider(),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 360, maxWidth: 600),
            child: HmiButton(
              key: const ValueKey('laser-enable-reminder-confirm'),
              label: l10n.laserEnableReminderConfirm,
              size: HmiButtonSize.large,
              widthPolicy: HmiButtonWidthPolicy.fill,
              variant: CyberButtonVariant.primary,
              shape: CyberButtonShape.rounded,
              onPressed: () {
                CyberClickSoundRegistry.playClick();
                Navigator.of(context).pop(
                  LaserEnableReminderResult(dontShowAgain: _dontShowAgain),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: CyberCheckbox(
            key: const ValueKey('laser-enable-reminder-dont-show-again'),
            value: _dontShowAgain,
            size: CyberDimens.checkboxLargeSize,
            onChanged: (v) {
              setState(() => _dontShowAgain = v ?? false);
            },
            label: Text(
              l10n.dontShowAgainThisSession,
              textAlign: TextAlign.center,
              style: context.hmiTypography.dialogOptionLabel.copyWith(
                color: _labelMuted,
                height: 1.0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.asset,
    required this.tip,
  });

  final String? asset;
  final String? tip;

  static const _cardFill = Color(0xFFF8F0E8);
  static const _tipDark = Color(0xFF1A1A1A);
  static const _illustrationSize = 200.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: _illustrationSize,
          height: _illustrationSize,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: _cardFill),
            child: Center(
              child: asset == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        asset!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // No fixed height — allow full tip lines.
        tip == null
            ? const SizedBox.shrink()
            : Text(
                tip!,
                textAlign: TextAlign.center,
                style: context.hmiTypography.reminderBody.copyWith(
                  color: _tipDark,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
      ],
    );
  }
}
