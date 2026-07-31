import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui Alarm Logs Clear success tip (`FrostStatusDialog` Cleared / Done / OK).
Future<void> showAlarmLogsClearedDialog({
  required BuildContext context,
}) {
  return CyberOverlayHost.show<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: CyberColors.scrim,
    freezePageBackdrop: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return _AlarmLogsClearedBody(
        title: l10n.alarmLogsClearedTitle,
        message: l10n.alarmLogsClearedMessage,
        okLabel: l10n.okText,
        onConfirm: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

final class _AlarmLogsClearedBody extends StatelessWidget {
  const _AlarmLogsClearedBody({
    required this.title,
    required this.message,
    required this.okLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String okLabel;
  final VoidCallback onConfirm;

  static const _maxWidth = 560.0;
  static const _iconSize = 80.0;
  static const _titleSize = 32.0;
  static const _bodySize = 20.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('alarm-logs-cleared-dialog'),
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: _titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Image(
              image: AssetImage(ProcessModeAssets.dialogSuccess),
              width: _iconSize,
              height: _iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: _bodySize,
              fontWeight: FontWeight.w400,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              child: SizedBox(
                width: double.infinity,
                child: CyberButton(
                  key: const ValueKey('alarm-logs-cleared-ok'),
                  variant: CyberButtonVariant.primary,
                  shape: CyberButtonShape.rounded,
                  stretch: true,
                  height: CyberDimens.actionButtonHeight,
                  onPressed: () {
                    CyberClickSoundRegistry.playClick();
                    onConfirm();
                  },
                  child: Text(okLabel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
