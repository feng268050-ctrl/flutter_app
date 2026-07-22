import 'package:cyber_ui/src/icons/cyber_connectivity_icon_phase.dart';
import 'package:flutter/material.dart';

/// Status-bar Bluetooth glyph (Material icon-font).
class CyberBluetoothStatusIcon extends StatelessWidget {
  const CyberBluetoothStatusIcon({
    super.key,
    required this.phase,
    this.size = 28,
  });

  final CyberConnectivityIconPhase phase;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (phase == CyberConnectivityIconPhase.hidden) {
      return const SizedBox.shrink();
    }

    final baseColor = switch (phase) {
      CyberConnectivityIconPhase.connected => Colors.white,
      CyberConnectivityIconPhase.connecting => Colors.white70,
      CyberConnectivityIconPhase.onIdle => Colors.white54,
      CyberConnectivityIconPhase.hidden => Colors.transparent,
    };

    final icon = switch (phase) {
      CyberConnectivityIconPhase.connected => Icons.bluetooth_connected,
      CyberConnectivityIconPhase.connecting => Icons.bluetooth_searching,
      CyberConnectivityIconPhase.onIdle => Icons.bluetooth,
      CyberConnectivityIconPhase.hidden => Icons.bluetooth,
    };

    return SizedBox(
      key: const ValueKey('cyber-status-bt'),
      width: size,
      height: size,
      child: Icon(icon, size: size * 0.92, color: baseColor),
    );
  }
}
