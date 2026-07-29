import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';

/// Provides [CloudSettingsStore] to the subtree.
final class CloudSettingsScope extends InheritedNotifier<CloudSettingsStore> {
  const CloudSettingsScope({
    super.key,
    required CloudSettingsStore store,
    required super.child,
  }) : super(notifier: store);

  static CloudSettingsStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CloudSettingsScope>();
    assert(scope != null, 'CloudSettingsScope not found');
    return scope!.notifier!;
  }

  static CloudSettingsStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CloudSettingsScope>()
        ?.notifier;
  }
}
