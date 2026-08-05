import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_settings_page.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Once-per-process Wi‑Fi connect tip on the global prompt queue.
abstract final class WifiConnectTipPrompt {
  static bool _enqueuedThisProcess = false;

  @visibleForTesting
  static void resetForTest() {
    _enqueuedThisProcess = false;
  }

  /// True while status-bar Wi‑Fi would show connecting/connected — tip is for
  /// radio-on idle / disconnected / failed only.
  @visibleForTesting
  static bool suppressesTip({
    required WifiRadioState radio,
    required WifiConnectionPhase phase,
  }) {
    if (radio == WifiRadioState.starting) {
      return true;
    }
    return phase == WifiConnectionPhase.associating ||
        phase == WifiConnectionPhase.obtainingIp ||
        phase == WifiConnectionPhase.connected;
  }

  /// Enqueue when Wi‑Fi radio is on but not connecting/connected. No-op if
  /// already enqueued this process or not eligible.
  static Future<void> enqueueIfNeeded({
    required GlobalPromptQueue queue,
    required AppServices services,
  }) {
    return enqueueForWifi(
      queue: queue,
      wifi: services.wifi,
      present: (host) => _present(host, services),
    );
  }

  /// Testable enroll path (no [AppServices] / wall-clock side effects).
  @visibleForTesting
  static Future<void> enqueueForWifi({
    required GlobalPromptQueue queue,
    required WifiController wifi,
    required Future<void> Function(GlobalPromptHost host) present,
  }) async {
    if (_enqueuedThisProcess) {
      return;
    }
    final radio = wifi.currentRadio;
    final conn = wifi.currentConnection;
    if (radio != WifiRadioState.on) {
      return;
    }
    if (suppressesTip(radio: radio, phase: conn.phase)) {
      return;
    }
    _enqueuedThisProcess = true;

    // Drop pending/showing tip once Wi‑Fi is connecting or associated.
    void maybeDismiss(WifiRadioState r, WifiConnectionPhase phase) {
      if (suppressesTip(radio: r, phase: phase)) {
        unawaited(queue.dismiss(GlobalPromptIds.wifiConnect));
      }
    }

    final autoCloseConn = wifi.connection.listen((state) {
      maybeDismiss(wifi.currentRadio, state.phase);
    });
    final autoCloseRadio = wifi.radio.listen((r) {
      maybeDismiss(r, wifi.currentConnection.phase);
    });
    try {
      await queue.enqueue(
        id: GlobalPromptIds.wifiConnect,
        present: present,
      );
    } finally {
      // Do not await cancel — dismiss may run inside a sync stream callback.
      unawaited(autoCloseConn.cancel());
      unawaited(autoCloseRadio.cancel());
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
    if (suppressesTip(
      radio: services.wifi.currentRadio,
      phase: services.wifi.currentConnection.phase,
    )) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    await TipDialogHost.showDarkPrompt<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return CyberPromptContent(
          title: l10n.wifiConnectTipTitle,
          body: Text(l10n.wifiConnectTipBody),
          actions: [
            HmiButton(
              label: l10n.closeText,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            HmiButton(
              label: l10n.wifiConnectTipOpenSettings,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.primary,
              onPressed: () {
                Navigator.of(ctx).pop();
                final nav = Navigator.of(context, rootNavigator: true);
                nav.push(
                  buildAppSlideRoute<void>(
                    builder: (_) => WifiSettingsPage(services: services),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
