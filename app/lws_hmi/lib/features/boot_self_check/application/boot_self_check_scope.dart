import 'package:flutter/material.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';

/// Provides [BootSelfCheckSettings] under the app tree.
final class BootSelfCheckScope extends InheritedWidget {
  const BootSelfCheckScope({
    super.key,
    required this.settings,
    required super.child,
  });

  final BootSelfCheckSettings settings;

  static BootSelfCheckScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BootSelfCheckScope>();
    assert(scope != null, 'BootSelfCheckScope not found');
    return scope!;
  }

  static BootSelfCheckScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BootSelfCheckScope>();
  }

  @override
  bool updateShouldNotify(BootSelfCheckScope oldWidget) =>
      settings != oldWidget.settings;
}
