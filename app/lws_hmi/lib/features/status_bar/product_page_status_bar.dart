import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/status_bar/live_product_status_items.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';

/// App binder around [CyberPageStatusBar] with live Wi‑Fi / BT / camera icons.
class ProductPageStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProductPageStatusBar({
    super.key,
    required this.title,
    this.onBack,
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
        CyberPageStatusBar buildBar() => CyberPageStatusBar(
              title: title,
              onBack: onBack,
              statusItems: items,
              actions: actions,
              bottom: bottom,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              toolbarHeight: toolbarHeight,
              clockNow: nowFn,
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
