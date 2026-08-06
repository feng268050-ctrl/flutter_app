import 'dart:async';

import 'package:cyber_upgrade_ui/src/domain/upgrade_completion_config.dart';
import 'package:cyber_upgrade_ui/src/domain/upgrade_progress.dart';
import 'package:flutter/widgets.dart';

/// When [progress] becomes terminal success and [config] is [autoReboot],
/// invokes [onAutoReboot] once after [UpgradeCompletionConfig.autoRebootDelay].
///
/// Use when the App (not the apply engine) owns reboot. For whole-device OTA,
/// `cyber_ota` already reboots after apply — leave [onAutoReboot] null unless
/// you intentionally move reboot out of the apply engine.
class UpgradePostApplyListener extends StatefulWidget {
  const UpgradePostApplyListener({
    super.key,
    required this.progress,
    required this.config,
    required this.child,
    this.onAutoReboot,
  });

  final UpgradeProgress progress;
  final UpgradeCompletionConfig config;
  final Widget child;

  /// Called once after the auto-reboot delay. Ignored when [config] is not
  /// [UpgradePostApplyAction.autoReboot] or when null.
  final Future<void> Function()? onAutoReboot;

  @override
  State<UpgradePostApplyListener> createState() =>
      _UpgradePostApplyListenerState();
}

class _UpgradePostApplyListenerState extends State<UpgradePostApplyListener> {
  Timer? _timer;
  var _armed = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant UpgradePostApplyListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.isTerminalOk != widget.progress.isTerminalOk ||
        oldWidget.config.postApplyAction != widget.config.postApplyAction ||
        oldWidget.config.autoRebootDelay != widget.config.autoRebootDelay ||
        oldWidget.onAutoReboot != widget.onAutoReboot) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.config.willAutoReboot ||
        !widget.progress.isTerminalOk ||
        widget.onAutoReboot == null ||
        _armed) {
      return;
    }
    _armed = true;
    final delay = widget.config.autoRebootDelay;
    final cb = widget.onAutoReboot!;
    if (delay <= Duration.zero) {
      unawaited(cb());
      return;
    }
    _timer = Timer(delay, () {
      unawaited(cb());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
