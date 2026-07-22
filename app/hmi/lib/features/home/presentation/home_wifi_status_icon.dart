import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/presentation/home_status_bar_phase.dart';
import 'package:lws_hmi/features/home/presentation/wifi_signal_bars.dart';

/// Top-right Home Wi‑Fi status glyph (arc bars by RSSI).
class HomeWifiStatusIcon extends StatelessWidget {
  const HomeWifiStatusIcon({
    super.key,
    required this.phase,
    this.signalDbm,
    this.size = 28,
  });

  final HomeConnectivityIconPhase phase;
  final int? signalDbm;
  final double size;

  /// Custom paint fills more of its box than Material glyphs; keep smaller
  /// so optical size matches [HomeBluetoothStatusIcon].
  static const double _glyphScale = 0.8;

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

    final glyphSize = size * _glyphScale;

    if (phase == HomeConnectivityIconPhase.connecting) {
      return SizedBox(
        key: const ValueKey('home-status-wifi'),
        width: size,
        height: size,
        child: Center(
          child: WifiSignalBarsConnecting(
            size: glyphSize,
            color: baseColor,
          ),
        ),
      );
    }

    final bars = phase == HomeConnectivityIconPhase.connected
        ? wifiSignalBarsFromDbm(signalDbm, linked: true)
        : 0;

    return SizedBox(
      key: const ValueKey('home-status-wifi'),
      width: size,
      height: size,
      child: Center(
        child: WifiSignalBars(
          level: bars,
          size: glyphSize,
          color: baseColor,
        ),
      ),
    );
  }
}
