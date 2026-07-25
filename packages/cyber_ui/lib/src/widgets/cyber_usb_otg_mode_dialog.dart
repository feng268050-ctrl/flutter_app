import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_button.dart';
import 'package:cyber_ui/src/widgets/cyber_dialog.dart';
import 'package:flutter/material.dart';

/// One row in [showCyberUsbOtgModeDialog].
final class CyberUsbOtgModeOption {
  const CyberUsbOtgModeOption({
    required this.id,
    required this.label,
  });

  /// Stable mode id (`debug` / `mtp` / `host`).
  final String id;

  /// Operator-visible label.
  final String label;
}

/// Standard English copy for the OTG mode picker.
abstract final class CyberUsbOtgModeCopy {
  static const title = 'Select USB Mode';
  static const debugLabel = 'Debug over USB';
  static const mtpLabel = 'Media Transfer Protocol';
  static const hostLabel = 'Connect Gadget';

  static const List<CyberUsbOtgModeOption> threeModes = [
    CyberUsbOtgModeOption(id: 'debug', label: debugLabel),
    CyberUsbOtgModeOption(id: 'mtp', label: mtpLabel),
    CyberUsbOtgModeOption(id: 'host', label: hostLabel),
  ];

  static const List<CyberUsbOtgModeOption> gadgetModes = [
    CyberUsbOtgModeOption(id: 'debug', label: debugLabel),
    CyberUsbOtgModeOption(id: 'mtp', label: mtpLabel),
  ];
}

/// Shows a reusable OTG mode picker. Returns selected mode id, or null if dismissed.
///
/// Does not depend on `cyber_hal` — the App maps the id to [UsbOtg.setMode].
Future<String?> showCyberUsbOtgModeDialog({
  required BuildContext context,
  List<CyberUsbOtgModeOption> options = CyberUsbOtgModeCopy.threeModes,
  String title = CyberUsbOtgModeCopy.title,
  bool barrierDismissible = true,
  bool useFakeGlass = false,
}) {
  return showCyberDialog<String>(
    context: context,
    barrierDismissible: barrierDismissible,
    useFakeGlass: useFakeGlass,
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Center(
              child: CyberButton(
                variant: CyberButtonVariant.standard,
                onPressed: () => Navigator.of(ctx).pop(options[i].id),
                child: Text(options[i].label),
              ),
            ),
          ],
        ],
      );
    },
  );
}
