import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';

/// Provides [DeviceRemoteLockStore] to status chrome / mode gates.
final class RemoteLockScope extends InheritedNotifier<DeviceRemoteLockStore> {
  const RemoteLockScope({
    super.key,
    required DeviceRemoteLockStore store,
    required super.child,
  }) : super(notifier: store);

  static DeviceRemoteLockStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RemoteLockScope>();
    assert(scope != null, 'RemoteLockScope not found');
    return scope!.notifier!;
  }

  static DeviceRemoteLockStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RemoteLockScope>()?.notifier;
  }
}
