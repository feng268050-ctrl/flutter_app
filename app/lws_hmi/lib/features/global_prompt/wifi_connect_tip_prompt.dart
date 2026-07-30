import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_settings_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Once-per-process Wi‑Fi connect tip on the global prompt queue.
abstract final class WifiConnectTipPrompt {
  static bool _enqueuedThisProcess = false;

  @visibleForTesting
  static void resetForTest() {
    _enqueuedThisProcess = false;
  }

  /// Enqueue when Wi‑Fi radio is on/starting but not connected. No-op if
  /// already enqueued this process or not eligible.
  static Future<void> enqueueIfNeeded({
    required GlobalPromptQueue queue,
    required AppServices services,
  }) async {
    if (_enqueuedThisProcess) {
      return;
    }
    final radio = services.wifi.currentRadio;
    final conn = services.wifi.currentConnection;
    final radioUp =
        radio == WifiRadioState.on || radio == WifiRadioState.starting;
    if (!radioUp) {
      return;
    }
    if (conn.phase == WifiConnectionPhase.connected) {
      return;
    }
    _enqueuedThisProcess = true;

    // Drop pending/showing tip as soon as Wi‑Fi associates (broadcast stream).
    final autoClose = services.wifi.connection.listen((state) {
      if (state.phase == WifiConnectionPhase.connected) {
        unawaited(queue.dismiss(GlobalPromptIds.wifiConnect));
      }
    });
    try {
      await queue.enqueue(
        id: GlobalPromptIds.wifiConnect,
        present: (host) => _present(host, services),
      );
    } finally {
      await autoClose.cancel();
    }
  }

  static Future<void> _present(
    GlobalPromptHost host,
    AppServices services,
  ) async {
    final context = host.context;
    if (!context.mounted) {
      return;
    }
    if (services.wifi.currentConnection.phase ==
        WifiConnectionPhase.connected) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    await CyberOverlayHost.show<void>(
      context: context,
      barrierDismissible: false,
      freezePageBackdrop: false,
      builder: (ctx) {
        return CyberPromptContent(
          title: l10n.wifiConnectTipTitle,
          body: Text(l10n.wifiConnectTipBody),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.closeText),
            ),
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () {
                Navigator.of(ctx).pop();
                final nav = Navigator.of(context, rootNavigator: true);
                nav.push(
                  MaterialPageRoute<void>(
                    builder: (_) => WifiSettingsPage(services: services),
                  ),
                );
              },
              child: Text(l10n.wifiConnectTipOpenSettings),
            ),
          ],
        );
      },
    );
  }
}
