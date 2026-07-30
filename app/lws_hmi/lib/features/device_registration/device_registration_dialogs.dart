import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/device/device_identity_qr.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/remote_lock_scope.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Registration / bind / remote-lock prompts for cloud device identity
/// (lws-ui parity). All prompts enqueue on [GlobalPromptQueue].
abstract final class DeviceRegistrationDialogs {
  static Future<void> enqueueRegistration({
    required GlobalPromptQueue queue,
    required AppServices services,
    required Future<void> Function() onReconnect,
    Future<void> Function()? onDismissedWithoutReconnect,
  }) {
    return queue.enqueue(
      id: GlobalPromptIds.deviceRegister,
      present: (host) => _presentRegistration(
        host: host,
        services: services,
        onReconnect: onReconnect,
        onDismissedWithoutReconnect: onDismissedWithoutReconnect,
      ),
    );
  }

  static Future<void> enqueueBindPrompt({
    required GlobalPromptQueue queue,
    required AppServices services,
  }) {
    return queue.enqueue(
      id: GlobalPromptIds.deviceBind,
      present: (host) => _presentBind(host: host, services: services),
    );
  }

  static Future<void> _presentRegistration({
    required GlobalPromptHost host,
    required AppServices services,
    required Future<void> Function() onReconnect,
    Future<void> Function()? onDismissedWithoutReconnect,
  }) async {
    final context = host.context;
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final snap = await services.sysInfo.snapshot();
    final model = productDeviceModelForQr(snap.brand, snap.model);
    final content = DeviceIdentityQr.contentV2(
      sn: snap.serialNumber ?? '',
      model: model,
      systemVersion: snap.appVersion ?? '',
    );
    if (!context.mounted) {
      return;
    }
    var reconnected = false;
    await CyberOverlayHost.show<void>(
      context: context,
      barrierDismissible: false,
      freezePageBackdrop: false,
      builder: (ctx) {
        return CyberPromptContent(
          title: l10n.deviceRegisterTitle,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.deviceRegisterBody),
              const SizedBox(height: 16),
              ColoredBox(
                color: Colors.white,
                child: QrImageView(
                  data: content,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancelText),
            ),
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () async {
                reconnected = true;
                Navigator.of(ctx).pop();
                await onReconnect();
              },
              child: Text(l10n.deviceRegisterReconnect),
            ),
          ],
        );
      },
    );
    // SN may have been registered via the QR while this dialog was open.
    // Re-probe so an empty users list can enqueue the bind prompt.
    if (!reconnected) {
      await onDismissedWithoutReconnect?.call();
    }
  }

  static Future<void> _presentBind({
    required GlobalPromptHost host,
    required AppServices services,
  }) async {
    final context = host.context;
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final snap = await services.sysInfo.snapshot();
    final model = productDeviceModelForQr(snap.brand, snap.model);
    final content = DeviceIdentityQr.contentV2(
      sn: snap.serialNumber ?? '',
      model: model,
      systemVersion: snap.appVersion ?? '',
    );
    if (!context.mounted) {
      return;
    }
    await CyberOverlayHost.show<void>(
      context: context,
      barrierDismissible: false,
      freezePageBackdrop: false,
      builder: (ctx) {
        return CyberPromptContent(
          title: l10n.deviceBindTitle,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.deviceBindBody),
              const SizedBox(height: 16),
              ColoredBox(
                color: Colors.white,
                child: QrImageView(
                  data: content,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.closeText),
            ),
          ],
        );
      },
    );
  }

  /// Returns `true` when not locked (or unlocked while the prompt was open).
  ///
  /// When locked, enqueues id [GlobalPromptIds.remoteLock] on the global
  /// prompt queue. Remote unlock dismisses that entry automatically.
  static Future<bool> confirmNotLocked(
    BuildContext context,
    DeviceRemoteLockStore lockStore, {
    GlobalPromptQueue? queue,
    bool useFakeGlass = false,
  }) async {
    lockStore.warmRead();
    if (!lockStore.isLocked) {
      return true;
    }
    final q = queue ?? GlobalPromptScope.of(context);

    void onLockChanged() {
      lockStore.warmRead();
      if (!lockStore.isLocked) {
        // Defer: setLocked may notify during a frame; popping mid-notify hangs.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(q.dismiss(GlobalPromptIds.remoteLock));
        });
      }
    }

    lockStore.addListener(onLockChanged);
    try {
      // Unlock may race before enqueue; dismiss is a no-op if never enqueued.
      onLockChanged();
      if (!lockStore.isLocked) {
        return true;
      }
      await q.enqueue(
        id: GlobalPromptIds.remoteLock,
        present: (host) => _presentRemoteLock(
          host: host,
          lockStore: lockStore,
          useFakeGlass: useFakeGlass,
        ),
      );
    } finally {
      lockStore.removeListener(onLockChanged);
    }
    lockStore.warmRead();
    return !lockStore.isLocked;
  }

  static Future<void> _presentRemoteLock({
    required GlobalPromptHost host,
    required DeviceRemoteLockStore lockStore,
    bool useFakeGlass = false,
  }) async {
    final context = host.context;
    if (!context.mounted) {
      return;
    }
    lockStore.warmRead();
    if (!lockStore.isLocked) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    // Widget tests: avoid CyberModal/BackdropFilter (can hang flutter_tester).
    if (useFakeGlass) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.deviceRemoteLockTitle),
            content: Text(l10n.deviceRemoteLockBody),
            actions: [
              TextButton(
                onPressed: () => host.close(),
                child: Text(l10n.closeText),
              ),
            ],
          );
        },
      );
      return;
    }
    await CyberOverlayHost.show<void>(
      context: context,
      barrierDismissible: false,
      freezePageBackdrop: false,
      builder: (ctx) {
        return CyberPromptContent(
          title: l10n.deviceRemoteLockTitle,
          body: Text(l10n.deviceRemoteLockBody),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => host.close(),
              child: Text(l10n.closeText),
            ),
          ],
        );
      },
    );
  }

  /// Preflight lock gate then [Navigator.pushNamed] (lws-ui home-entry parity).
  ///
  /// Returns `false` when locked (dialog shown, no navigation) or the context
  /// unmounted; otherwise starts the named route and returns `true` immediately
  /// (does not wait for the route to pop).
  static Future<bool> pushNamedIfUnlocked(
    BuildContext context,
    String routeName, {
    Object? arguments,
    DeviceRemoteLockStore? lockStore,
    GlobalPromptQueue? queue,
    bool useFakeGlass = false,
  }) async {
    final store = lockStore ?? RemoteLockScope.of(context);
    final ok = await confirmNotLocked(
      context,
      store,
      queue: queue,
      useFakeGlass: useFakeGlass,
    );
    if (!ok || !context.mounted) {
      return false;
    }
    // Fire-and-forget: awaiting pushNamed would block until the route pops.
    unawaited(
      Navigator.of(context).pushNamed(routeName, arguments: arguments),
    );
    return true;
  }
}
