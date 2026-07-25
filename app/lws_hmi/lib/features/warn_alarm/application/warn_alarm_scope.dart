import 'package:flutter/material.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';

/// Provides [WarnAlarmController] to Monitor / shell.
final class WarnAlarmScope extends InheritedWidget {
  const WarnAlarmScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final WarnAlarmController controller;

  static WarnAlarmController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WarnAlarmScope>();
    assert(scope != null, 'WarnAlarmScope not found');
    return scope!.controller;
  }

  static WarnAlarmController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WarnAlarmScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(WarnAlarmScope oldWidget) =>
      controller != oldWidget.controller;
}
