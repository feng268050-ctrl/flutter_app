import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';

/// Provides [CommonSettingsStore] under the app tree.
final class CommonSettingsScope extends InheritedWidget {
  const CommonSettingsScope({
    super.key,
    required this.store,
    required super.child,
  });

  final CommonSettingsStore store;

  static CommonSettingsStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CommonSettingsScope>();
    assert(scope != null, 'CommonSettingsScope not found');
    return scope!.store;
  }

  static CommonSettingsStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CommonSettingsScope>()
        ?.store;
  }

  @override
  bool updateShouldNotify(CommonSettingsScope oldWidget) =>
      store != oldWidget.store;
}
