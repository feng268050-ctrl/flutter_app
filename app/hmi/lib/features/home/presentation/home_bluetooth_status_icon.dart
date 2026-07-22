import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/presentation/home_status_bar_phase.dart';

/// Top-right Home Bluetooth status glyph (Material icon-font).
class HomeBluetoothStatusIcon extends StatelessWidget {
  const HomeBluetoothStatusIcon({
    super.key,
    required this.phase,
    this.size = 28,
  });

  final HomeConnectivityIconPhase phase;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (phase == HomeConnectivityIconPhase.hidden) {
      return const SizedBox.shrink();
    }

    final baseColor = switch (phase) {
      HomeConnectivityIconPhase.connected => Colors.white,
      HomeConnectivityIconPhase.connecting => Colors.white70,
      HomeConnectivityIconPhase.onIdle => Colors.white54,
      HomeConnectivityIconPhase.hidden => Colors.transparent,
    };

    final icon = switch (phase) {
      HomeConnectivityIconPhase.connected => Icons.bluetooth_connected,
      HomeConnectivityIconPhase.connecting => Icons.bluetooth_searching,
      HomeConnectivityIconPhase.onIdle => Icons.bluetooth,
      HomeConnectivityIconPhase.hidden => Icons.bluetooth,
    };

    return SizedBox(
      key: const ValueKey('home-status-bt'),
      width: size,
      height: size,
      child: Icon(icon, size: size * 0.92, color: baseColor),
    );
  }
}
