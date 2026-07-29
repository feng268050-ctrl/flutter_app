import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime.dart';

/// Provides [CloudLocalRuntime] to Home prompt / registration flows.
final class CloudLocalRuntimeScope extends InheritedWidget {
  const CloudLocalRuntimeScope({
    super.key,
    required this.runtime,
    required super.child,
  });

  final CloudLocalRuntime runtime;

  static CloudLocalRuntime of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CloudLocalRuntimeScope>();
    assert(scope != null, 'CloudLocalRuntimeScope not found');
    return scope!.runtime;
  }

  static CloudLocalRuntime? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CloudLocalRuntimeScope>()
        ?.runtime;
  }

  @override
  bool updateShouldNotify(CloudLocalRuntimeScope oldWidget) =>
      runtime != oldWidget.runtime;
}
