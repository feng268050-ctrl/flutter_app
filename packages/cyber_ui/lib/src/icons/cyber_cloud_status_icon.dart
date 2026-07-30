import 'package:flutter/material.dart';

/// Status-bar cloud link glyph (device ↔ cloud WebSocket).
///
/// Shown ahead of Wi‑Fi when the LAN is up: dim while waiting for WS,
/// lit when the device WebSocket is connected.
class CyberCloudStatusIcon extends StatelessWidget {
  const CyberCloudStatusIcon({
    super.key,
    required this.linked,
    this.size = 28,
  });

  /// True when the device cloud WebSocket is connected.
  final bool linked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('cyber-status-cloud'),
      width: size,
      height: size,
      child: Icon(
        Icons.cloud,
        size: size * 0.88,
        color: linked ? Colors.white : Colors.white54,
      ),
    );
  }
}
