import 'package:cyber_hal/locale.dart';
import 'package:flutter/material.dart';

/// Provides HAL [LocaleSettings] under the app tree (General Language/Unit/Region).
final class CommonSettingsScope extends InheritedWidget {
  const CommonSettingsScope({
    super.key,
    required this.store,
    required super.child,
  });

  final LocaleSettings store;

  static LocaleSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CommonSettingsScope>();
    assert(scope != null, 'CommonSettingsScope not found');
    return scope!.store;
  }

  static LocaleSettings? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CommonSettingsScope>()
        ?.store;
  }

  @override
  bool updateShouldNotify(CommonSettingsScope oldWidget) =>
      store != oldWidget.store;
}
