import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// In-panel version-check presentation states (Settings System Upgrade).
enum UpgradeCheckUiState {
  idle,
  checking,
  upToDate,
  available,
  unavailable,
  failed,
}

/// Settings-style check status body with injected copy.
///
/// Actions (Update Now / Check / Later) are supplied by the App via [actions]
/// so product buttons (e.g. HmiButton) stay App-owned.
class UpgradeCheckCard extends StatelessWidget {
  const UpgradeCheckCard({
    super.key,
    required this.state,
    this.idleHint,
    this.checkingLabel,
    this.upToDateMessage,
    this.unavailableMessage,
    this.failedMessage,
    this.availableHeadline,
    this.availableBody,
    this.statusStyle,
    this.headlineStyle,
    this.actions,
    this.checkingIndicatorColor = CyberColors.buttonPrimaryFill,
  });

  final UpgradeCheckUiState state;

  final String? idleHint;
  final String? checkingLabel;
  final String? upToDateMessage;
  final String? unavailableMessage;
  final String? failedMessage;
  final String? availableHeadline;
  final String? availableBody;

  final TextStyle? statusStyle;
  final TextStyle? headlineStyle;

  /// Footer actions under the status body (optional).
  final Widget? actions;

  final Color checkingIndicatorColor;

  @override
  Widget build(BuildContext context) {
    final style = statusStyle ??
        const TextStyle(
          color: CyberColors.textSecondary,
          height: 1.4,
          fontSize: 22,
        );

    final status = switch (state) {
      UpgradeCheckUiState.idle => Text(idleHint ?? '', style: style),
      UpgradeCheckUiState.checking => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: checkingIndicatorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              checkingLabel ?? '',
              textAlign: TextAlign.center,
              style: style,
            ),
          ],
        ),
      UpgradeCheckUiState.upToDate => Text(upToDateMessage ?? '', style: style),
      UpgradeCheckUiState.unavailable =>
        Text(unavailableMessage ?? '', style: style),
      UpgradeCheckUiState.failed => Text(failedMessage ?? '', style: style),
      UpgradeCheckUiState.available => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (availableHeadline != null && availableHeadline!.isNotEmpty)
              Text(
                availableHeadline!,
                style: headlineStyle ??
                    const TextStyle(
                      color: CyberColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            if (availableBody != null && availableBody!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(availableBody!, style: style),
            ],
          ],
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: state == UpgradeCheckUiState.checking
                ? Alignment.center
                : Alignment.topCenter,
            child: status,
          ),
        ),
        if (actions != null) actions!,
      ],
    );
  }
}
