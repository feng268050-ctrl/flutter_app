import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Confirm-style dialog content for TipDialogHost / frost prompts.
///
/// App supplies [actions] (Cancel / OK widgets) and localized [title]/[body].
class UpgradeCheckDialogContent extends StatelessWidget {
  const UpgradeCheckDialogContent({
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

/// Alias matching the design name [UpgradeCheckDialog].
typedef UpgradeCheckDialog = UpgradeCheckDialogContent;
