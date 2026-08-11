import 'package:cyber_hal/bluetooth.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/app/services.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/util/status_bar_phase.dart';

/// OS Settings binder around [CyberPageStatusBar] (same cyber_ui chrome as HMI).
class OsSettingsPageStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const OsSettingsPageStatusBar({
    super.key,
    required this.title,
    this.onBack,
    this.backLabel,
    this.backAccent = CyberStatusBarAccent.weld,
    this.backEnabled = true,
    this.actions,
    this.iconSize = 34,
    this.toolbarHeight = kToolbarHeight,
    this.clockListenable,
  });

  final String title;
  final VoidCallback? onBack;
  final String? backLabel;
  final CyberStatusBarAccent backAccent;
  final bool backEnabled;
  final List<Widget>? actions;
  final double iconSize;
  final double toolbarHeight;
  final Listenable? clockListenable;

  @override
  Size get preferredSize {
    return Size.fromHeight(
      toolbarHeight + SettingsStatusBarFadeDivider.thickness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = OsSettingsScope.maybeOf(context);
    final services = scope?.services;
    final useCallBackHome = onBack != null && backLabel != null;
    final listenable = clockListenable ?? services?.wallClock;
    final clockFg = CyberColors.textPrimary;

    CyberPageStatusBar buildBar() => CyberPageStatusBar(
          title: title,
          onBack: useCallBackHome ? null : onBack,
          leading: useCallBackHome
              ? CallBackHomeButton(
                  accent: backAccent,
                  label: backLabel!,
                  enabled: backEnabled,
                  showEdgeAccent: false,
                  onPressed: onBack!,
                )
              : (onBack != null && !backEnabled
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: CyberColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      onPressed: null,
                    )
                  : null),
          leadingWidth:
              useCallBackHome ? CallBackHomeButton.railWidth : null,
          statusItems: services == null
              ? const <Widget>[]
              : [
                  _OsWifiStatusIcon(services: services, size: iconSize),
                  _OsBluetoothStatusIcon(services: services, size: iconSize),
                ],
          actions: actions,
          backgroundColor: Colors.transparent,
          foregroundColor: CyberColors.textPrimary,
          toolbarHeight: toolbarHeight,
          clockNow: services != null ? () => services.wallClock.now : null,
          use24HourFormat: services?.wallClock.use24HourFormat ?? true,
          clockStyle: TextStyle(
            color: clockFg,
            fontSize: CallBackHomeButton.labelFontSize,
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          bottom: const PreferredSize(
            preferredSize:
                Size.fromHeight(SettingsStatusBarFadeDivider.thickness),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: SettingsDimens.inset),
              child: SettingsStatusBarFadeDivider(),
            ),
          ),
        );

    if (listenable == null) {
      return buildBar();
    }
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => buildBar(),
    );
  }
}

class _OsWifiStatusIcon extends StatelessWidget {
  const _OsWifiStatusIcon({required this.services, required this.size});

  final OsSettingsServices services;
  final double size;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WifiRadioState>(
      stream: services.wifi().radio,
      initialData: services.wifi().currentRadio,
      builder: (context, radioSnap) {
        return StreamBuilder<WifiConnectionState>(
          stream: services.wifi().connection,
          initialData: services.wifi().currentConnection,
          builder: (context, connSnap) {
            final phase = mapWifiStatusBarPhase(
              radio: radioSnap.data ?? WifiRadioState.off,
              conn: connSnap.data ?? WifiConnectionState.disconnected,
            );
            return CyberWifiStatusIcon(
              phase: phase,
              signalDbm: connSnap.data?.signalDbm,
              size: size,
            );
          },
        );
      },
    );
  }
}

class _OsBluetoothStatusIcon extends StatelessWidget {
  const _OsBluetoothStatusIcon({required this.services, required this.size});

  final OsSettingsServices services;
  final double size;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothAdapterState>(
      stream: services.bluetooth().adapterState,
      initialData: services.bluetooth().currentAdapterState,
      builder: (context, stateSnap) {
        return StreamBuilder<BluetoothPairingChallenge?>(
          stream: services.bluetooth().pairingChallenge,
          initialData: services.bluetooth().currentPairingChallenge,
          builder: (context, challengeSnap) {
            final phase = mapBluetoothStatusBarPhase(
              adapter: stateSnap.data ?? BluetoothAdapterState.off,
              devices: services.bluetooth().currentDevices,
              pairingChallenge: challengeSnap.data,
            );
            return CyberBluetoothStatusIcon(phase: phase, size: size);
          },
        );
      },
    );
  }
}
