import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/src/domain/upgrade_completion_config.dart';
import 'package:cyber_upgrade_ui/src/domain/upgrade_progress.dart';
import 'package:flutter/material.dart';

/// Inline completion tip for terminal success / failure.
///
/// Success copy follows [UpgradeCompletionConfig.postApplyAction]:
/// - [UpgradePostApplyAction.autoReboot] → show imminent-reboot notice (OTA)
/// - [UpgradePostApplyAction.none] → no reboot implication (control-board)
class UpgradeCompletionTip extends StatelessWidget {
  const UpgradeCompletionTip({
    super.key,
    required this.progress,
    required this.config,
    this.style,
    this.titleStyle,
  });

  final UpgradeProgress progress;
  final UpgradeCompletionConfig config;
  final TextStyle? style;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    if (!progress.isTerminalOk && !progress.isTerminalFail) {
      return const SizedBox.shrink();
    }

    final secondary = style ??
        const TextStyle(
          color: CyberColors.textSecondary,
          fontSize: 16,
          height: 1.4,
        );
    final title = titleStyle ??
        const TextStyle(
          color: CyberColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );

    if (progress.isTerminalFail) {
      final body = config.failureBody ?? progress.errorMessage ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (config.failureTitle != null && config.failureTitle!.isNotEmpty)
            Text(
              config.failureTitle!,
              textAlign: TextAlign.center,
              style: title,
            ),
          if (body.isNotEmpty) ...[
            if (config.failureTitle != null) const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: secondary),
          ],
        ],
      );
    }

    // Success — never claim success on fail (guarded above).
    final hint = config.successHint?.trim();
    final showAutoRebootNotice =
        config.willAutoReboot && hint != null && hint.isNotEmpty;
    final showOptionalHint =
        !config.willAutoReboot && hint != null && hint.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (config.successTitle != null && config.successTitle!.isNotEmpty)
          Text(
            config.successTitle!,
            textAlign: TextAlign.center,
            style: title,
          ),
        if (config.successBody != null && config.successBody!.isNotEmpty) ...[
          if (config.successTitle != null) const SizedBox(height: 12),
          Text(
            config.successBody!,
            textAlign: TextAlign.center,
            style: secondary,
          ),
        ],
        if (showAutoRebootNotice || showOptionalHint) ...[
          const SizedBox(height: 16),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: secondary,
          ),
        ],
      ],
    );
  }
}

/// Dialog-oriented completion content (success / fail TipDialogHost).
class UpgradeCompletionDialogContent extends StatelessWidget {
  const UpgradeCompletionDialogContent({
    super.key,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.tone = CyberTone.dark,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final CyberTone tone;

  @override
  Widget build(BuildContext context) {
    return CyberPromptContent(
      title: title,
      body: body,
      actions: actions,
      tone: tone,
    );
  }
}
