import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/status_bar/call_back_home_button.dart';
import 'package:lws_hmi/features/status_bar/live_product_status_items.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';

/// App binder around [CyberPageStatusBar] with live Wi‑Fi / BT / camera icons.
class ProductPageStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProductPageStatusBar({
    super.key,
    required this.title,
    this.onBack,
    this.backEnabled = true,
    this.backLabel,
    this.backAccent = WorkModeAccent.weld,
    this.useHomeIcon,
    this.centerClock = false,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.cameraStatus,
    // Settings / Monitor (+ nested) trailing icons — match Back glyph (34).
    this.iconSize = 34,
    this.wifi,
    this.bluetooth,
    this.toolbarHeight = kToolbarHeight,
    this.clockNow,
    this.clockListenable,
  });

  final String title;
  final VoidCallback? onBack;

  /// When false, the product Back/Home control stays visible but disabled
  /// (grayed) — used while an upgrade transfer must not be left.
  final bool backEnabled;

  /// When set with [onBack], uses the product [CallBackHomeButton] (icon +
  /// label + accent press FX) instead of the Material arrow back.
  ///
  /// Settings / Monitor pass the page or tab title here (not a fixed Back/Home
  /// string) when [centerClock] is true.
  final String? backLabel;

  /// Press / edge accent for [CallBackHomeButton]. Defaults to product orange.
  final WorkModeAccent backAccent;

  /// Forwarded to [CallBackHomeButton.useHomeIcon] (Settings/Monitor roots).
  final bool? useHomeIcon;

  /// Settings / Monitor: clock centered; trailing side is icons only.
  final bool centerClock;

  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IpCameraUiStatus? cameraStatus;
  final double iconSize;
  final WifiController? wifi;
  final BluetoothController? bluetooth;
  final double toolbarHeight;
  final DateTime Function()? clockNow;
  final Listenable? clockListenable;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(toolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.maybeOf(context);
    final listenable = clockListenable ?? services?.wallClock;
    final nowFn =
        clockNow ?? (services != null ? () => services.wallClock.now : null);

    return LiveProductStatusItems(
      cameraStatus: cameraStatus,
      iconSize: iconSize,
      wifi: wifi,
      bluetooth: bluetooth,
      builder: (context, items) {
        final useCallBackHome = onBack != null && backLabel != null;
        // Settings / Monitor (centerClock): full title label, no orange edges.
        final settingsMonitorBack = centerClock && useCallBackHome;
        final theme = Theme.of(context);
        final clockFg = foregroundColor ??
            theme.appBarTheme.foregroundColor ??
            theme.colorScheme.onSurface;
        CyberPageStatusBar buildBar() => CyberPageStatusBar(
              // When the clock is centered, AppBar title is the clock widget.
              title: centerClock ? '' : title,
              centerClock: centerClock,
              onBack: useCallBackHome ? null : onBack,
              leading: useCallBackHome
                  ? CallBackHomeButton(
                      accent: backAccent,
                      label: backLabel!,
                      enabled: backEnabled,
                      useHomeIcon: useHomeIcon,
                      expandWidth: !settingsMonitorBack,
                      showEdgeAccent: !settingsMonitorBack,
                      onPressed: onBack!,
                    )
                  : null,
              leadingWidth: useCallBackHome
                  ? (settingsMonitorBack
                      ? CallBackHomeButton.widthForLabel(
                          backLabel!,
                          textScaler: MediaQuery.textScalerOf(context),
                        )
                      : CallBackHomeButton.railWidth)
                  : null,
              statusItems: items,
              actions: actions,
              bottom: bottom,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              toolbarHeight: toolbarHeight,
              clockNow: nowFn,
              use24HourFormat: services?.wallClock.use24HourFormat ?? true,
              // Match Settings / Monitor Back label size.
              clockStyle: TextStyle(
                color: clockFg,
                fontSize: CallBackHomeButton.labelFontSize,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
        if (listenable == null) {
          return buildBar();
        }
        return ListenableBuilder(
          listenable: listenable,
          builder: (context, _) => buildBar(),
        );
      },
    );
  }
}
