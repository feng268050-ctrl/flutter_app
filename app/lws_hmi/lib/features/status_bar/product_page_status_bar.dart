import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/status_bar/call_back_home_button.dart';
import 'package:lws_hmi/features/status_bar/live_product_status_items.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';

/// App binder around [CyberPageStatusBar] with live Wi‑Fi / BT / camera icons.
class ProductPageStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProductPageStatusBar({
    super.key,
    required this.title,
    this.onBack,
    this.backLabel,
    this.backAccent = WorkModeAccent.weld,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.cameraStatus,
    this.iconSize = 24,
    this.wifi,
    this.bluetooth,
    this.toolbarHeight = kToolbarHeight,
    this.clockNow,
    this.clockListenable,
  });

  final String title;
  final VoidCallback? onBack;

  /// When set with [onBack], uses the product [CallBackHomeButton] (icon +
  /// label + accent press FX) instead of the Material arrow back.
  ///
  /// Keep this label fixed (e.g. Home) when [title] changes with tabs.
  final String? backLabel;

  /// Press / edge accent for [CallBackHomeButton]. Defaults to product orange.
  final WorkModeAccent backAccent;
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
        final theme = Theme.of(context);
        final clockFg = foregroundColor ??
            theme.appBarTheme.foregroundColor ??
            theme.colorScheme.onSurface;
        CyberPageStatusBar buildBar() => CyberPageStatusBar(
              title: title,
              onBack: useCallBackHome ? null : onBack,
              leading: useCallBackHome
                  ? CallBackHomeButton(
                      accent: backAccent,
                      label: backLabel!,
                      onPressed: onBack!,
                    )
                  : null,
              leadingWidth:
                  useCallBackHome ? CallBackHomeButton.railWidth : null,
              statusItems: items,
              actions: actions,
              bottom: bottom,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              toolbarHeight: toolbarHeight,
              clockNow: nowFn,
              // Match Quick / Engineer [WorkModeStatusBar] clock size.
              clockStyle: TextStyle(
                color: clockFg,
                fontSize: WorkModeStatusBarDimens.chromeLabelFontSize,
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
