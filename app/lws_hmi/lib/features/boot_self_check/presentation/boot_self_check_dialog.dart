import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_session.dart';
import 'package:lws_hmi/features/boot_self_check/domain/boot_self_check_item.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

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
                    style: const TextStyle(
                      color: CyberColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                                  style: const TextStyle(
                                    color: CyberColors.textPrimary,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Text(
                                row.status.labelFor(l10n),
                                style: TextStyle(
                                  color: _statusColor(row.status),
                                  fontSize: 16,
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
                    const Divider(height: 1, color: Color(0x44FFFFFF)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CyberCheckbox(
                          value: session.dontShowAgain,
                          size: CyberDimens.checkboxLargeSize,
                          onChanged: (v) {
                            onUserInteracted?.call();
                            session.setDontShowAgain(v ?? false);
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.bootSelfCheckDontShowAgain,
                            style: const TextStyle(
                              color: CyberColors.textSecondary,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        CyberButton(
                          variant: CyberButtonVariant.primary,
                          onPressed: () {
                            onUserInteracted?.call();
                            onClose();
                          },
                          child: Text(l10n.bootSelfCheckClose),
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
