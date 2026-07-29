import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/device/device_identity_qr.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Registration / bind dialogs for cloud device identity (lws-ui parity).
abstract final class DeviceRegistrationDialogs {
  static bool _registrationShowing = false;
  static bool _bindShowing = false;

  static Future<void> showRegistration({
    required BuildContext context,
    required AppServices services,
    required Future<void> Function() onReconnect,
  }) async {
    if (_registrationShowing || !context.mounted) {
      return;
    }
    _registrationShowing = true;
    try {
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
      await showCyberDialog<void>(
        context: context,
        builder: (ctx) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.deviceRegisterTitle,
                style: const TextStyle(
                  fontSize: 20,
                  color: CyberColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.deviceRegisterBody,
                style: const TextStyle(color: CyberColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: content,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CyberButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n.cancelText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CyberButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await onReconnect();
                      },
                      child: Text(l10n.deviceRegisterReconnect),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } finally {
      _registrationShowing = false;
    }
  }

  static Future<void> showBindPrompt({
    required BuildContext context,
    required AppServices services,
  }) async {
    if (_bindShowing || !context.mounted) {
      return;
    }
    _bindShowing = true;
    try {
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
      await showCyberDialog<void>(
        context: context,
        builder: (ctx) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.deviceBindTitle,
                style: const TextStyle(
                  fontSize: 20,
                  color: CyberColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.deviceBindBody,
                style: const TextStyle(color: CyberColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: content,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              CyberButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.closeText),
              ),
            ],
          );
        },
      );
    } finally {
      _bindShowing = false;
    }
  }

  static Future<bool> confirmNotLocked(
    BuildContext context,
    DeviceRemoteLockStore lockStore,
  ) async {
    lockStore.warmRead();
    if (!lockStore.isLocked) {
      return true;
    }
    final l10n = AppLocalizations.of(context)!;
    await showCyberDialog<void>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.deviceRemoteLockTitle,
              style: const TextStyle(
                fontSize: 20,
                color: CyberColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.deviceRemoteLockBody,
              style: const TextStyle(color: CyberColors.textSecondary),
            ),
            const SizedBox(height: 20),
            CyberButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.closeText),
            ),
          ],
        );
      },
    );
    return false;
  }
}
