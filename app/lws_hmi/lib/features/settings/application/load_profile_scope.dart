import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/load_profile_controller.dart';

/// Provides [LoadProfileController] under the app tree.
final class LoadProfileScope extends InheritedNotifier<LoadProfileController> {
  const LoadProfileScope({
    super.key,
    required LoadProfileController controller,
    required super.child,
  }) : super(notifier: controller);

  static LoadProfileController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LoadProfileScope>();
    assert(scope != null, 'LoadProfileScope not found');
    return scope!.notifier!;
  }

  static LoadProfileController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LoadProfileScope>()
        ?.notifier;
  }
}
