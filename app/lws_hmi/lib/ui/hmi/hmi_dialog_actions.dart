import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Standard Cancel / Confirm row for ordinary dialogs (100% medium + equal).
final class HmiDialogActions extends StatelessWidget {
  const HmiDialogActions({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.equalWidth = 168,
    this.gap = 24,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final double equalWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HmiButton(
          label: cancelLabel,
          size: HmiButtonSize.medium,
          widthPolicy: HmiButtonWidthPolicy.equal,
          width: equalWidth,
          variant: CyberButtonVariant.secondary,
          onPressed: onCancel,
        ),
        SizedBox(width: gap),
        HmiButton(
          label: confirmLabel,
          size: HmiButtonSize.medium,
          widthPolicy: HmiButtonWidthPolicy.equal,
          width: equalWidth,
          variant: CyberButtonVariant.primary,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}
