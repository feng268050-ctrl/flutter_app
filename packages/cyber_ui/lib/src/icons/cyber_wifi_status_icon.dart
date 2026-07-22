import 'package:cyber_ui/src/icons/cyber_connectivity_icon_phase.dart';
import 'package:cyber_ui/src/icons/cyber_wifi_signal_bars.dart';
import 'package:flutter/material.dart';

/// Status-bar Wi‑Fi glyph (arc bars by RSSI).
class CyberWifiStatusIcon extends StatelessWidget {
  const CyberWifiStatusIcon({
    super.key,
    required this.phase,
    this.signalDbm,
    this.size = 28,
  });

  final CyberConnectivityIconPhase phase;
  final int? signalDbm;
  final double size;

  /// Custom paint fills more of its box than Material glyphs; keep smaller
  /// so optical size matches [CyberBluetoothStatusIcon].
  static const double _glyphScale = 0.8;

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

    final glyphSize = size * _glyphScale;

    if (phase == CyberConnectivityIconPhase.connecting) {
      return SizedBox(
        key: const ValueKey('cyber-status-wifi'),
        width: size,
        height: size,
        child: Center(
          child: CyberWifiSignalBarsConnecting(
            size: glyphSize,
            color: baseColor,
          ),
        ),
      );
    }

    final bars = phase == CyberConnectivityIconPhase.connected
        ? cyberWifiSignalBarsFromDbm(signalDbm, linked: true)
        : 0;

    return SizedBox(
      key: const ValueKey('cyber-status-wifi'),
      width: size,
      height: size,
      child: Center(
        child: CyberWifiSignalBars(
          level: bars,
          size: glyphSize,
          color: baseColor,
        ),
      ),
    );
  }
}
