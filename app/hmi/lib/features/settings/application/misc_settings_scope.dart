import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';

/// Provides [MiscSettingsStore] under the app tree.
final class MiscSettingsScope extends InheritedWidget {
  const MiscSettingsScope({
    super.key,
    required this.store,
    required super.child,
  });

  final MiscSettingsStore store;

  static MiscSettingsStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MiscSettingsScope>();
    assert(scope != null, 'MiscSettingsScope not found');
    return scope!.store;
  }

  static MiscSettingsStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MiscSettingsScope>()
        ?.store;
  }

  @override
  bool updateShouldNotify(MiscSettingsScope oldWidget) =>
      store != oldWidget.store;
}
