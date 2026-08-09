import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_session.dart';
import 'package:lws_hmi/features/boot_self_check/domain/boot_self_check_item.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Max height for the item list before it scrolls (lws-ui `maxHeight="420dp"`).
const double _kItemListMaxHeight = 420;

/// Cyber overlay body for boot self-check (lws-ui `BootSelfCheckDialog`).
class BootSelfCheckDialogBody extends StatelessWidget {
  const BootSelfCheckDialogBody({
    super.key,
    required this.session,
    required this.onClose,
    this.onUserInteracted,
  });

  final BootSelfCheckSession session;
  final VoidCallback onClose;
  final VoidCallback? onUserInteracted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => onUserInteracted?.call(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.bootSelfCheckDialogTitle,
                    textAlign: TextAlign.center,
                    style: context.hmiTypography.pageTitle.copyWith(
                      color: CyberColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TipFrostDivider(),
                  const SizedBox(height: 16),
                  // Shrink-wrap while short; scroll only when taller than max
                  // (lws-ui ScrollView + maxHeight on the item list).
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: _kItemListMaxHeight,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: session.rows.length,
                      itemBuilder: (context, i) {
                        final row = session.rows[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.item.labelFor(l10n),
                                  style:
                                      context.hmiTypography.buttonLarge.copyWith(
                                    color: CyberColors.textPrimary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              Text(
                                row.status.labelFor(l10n),
                                style: context.hmiTypography.sectionTitle
                                    .copyWith(
                                  color: _statusColor(row.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (session.showFooter) ...[
                    const SizedBox(height: 16),
                    const TipFrostDivider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CyberCheckbox(
                            value: session.dontShowAgain,
                            size: CyberDimens.checkboxLargeSize,
                            expandLabel: true,
                            onChanged: (v) {
                              onUserInteracted?.call();
                              session.setDontShowAgain(v ?? false);
                            },
                            label: Text(
                              l10n.bootSelfCheckDontShowAgain,
                              style: context.hmiTypography.dialogOptionLabel
                                  .copyWith(
                                color: CyberColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        HmiButton(
                          label: l10n.bootSelfCheckClose,
                          size: HmiButtonSize.large,
                          variant: CyberButtonVariant.primary,
                          onPressed: () {
                            onUserInteracted?.call();
                            onClose();
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _statusColor(BootSelfCheckStatus status) {
    switch (status) {
      case BootSelfCheckStatus.checking:
        return CyberColors.textSecondary;
      case BootSelfCheckStatus.pass:
        return const Color(0xFF5AD67D);
      case BootSelfCheckStatus.fail:
        return const Color(0xFFFF6B6B);
      case BootSelfCheckStatus.skipped:
        return CyberColors.textSecondary;
    }
  }
}

/// Shows the self-check overlay; returns when dismissed.
///
/// Spec / [CyberOverlayHost]: full-screen opaque [barrierColor] sits *under*
/// the panel, so realtime [BackdropFilter] would blur the scrim instead of
/// Home — keep the barrier transparent. Frost comes from panel
/// [CyberBackdropBlur] (realtime) + tint overlay, not the modal barrier.
Future<void> showBootSelfCheckDialog({
  required BuildContext context,
  required BootSelfCheckSession session,
  required VoidCallback onClose,
  VoidCallback? onUserInteracted,
}) {
  return CyberOverlayHost.show<void>(
    context: context,
    barrierDismissible: false,
    // Transparent: realtime frost must sample Home wallpaper, not a dim scrim.
    barrierColor: Colors.transparent,
    freezePageBackdrop: false,
    useFakeGlass: false,
    sampleMode: CyberBlurSampleMode.realtime,
    intensity: CyberBlurIntensity.high,
    blurTint: CyberBlurTint.dark,
    tone: CyberTone.dark,
    builder: (dialogContext) {
      return BootSelfCheckDialogBody(
        session: session,
        onClose: onClose,
        onUserInteracted: onUserInteracted,
      );
    },
  );
}
