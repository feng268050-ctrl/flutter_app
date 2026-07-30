import 'package:cyber_ui/src/icons/cyber_cloud_link_status.dart';
import 'package:cyber_ui/src/icons/cyber_status_icon_spin.dart';
import 'package:flutter/material.dart';

/// Status-bar cloud link glyph (API origin probe → device WebSocket).
///
/// Shown ahead of Wi‑Fi when the LAN is up. Mirrors [CyberCameraStatusIcon]
/// corner marks: spinner while linking, cancel when failed, lit when up.
class CyberCloudStatusIcon extends StatelessWidget {
  const CyberCloudStatusIcon({
    super.key,
    required this.status,
    this.size = 28,
  });

  final CyberCloudLinkStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final baseColor = switch (status) {
      CyberCloudLinkStatus.connected => Colors.white,
      CyberCloudLinkStatus.connecting => Colors.white70,
      CyberCloudLinkStatus.failed => Colors.white54,
    };

    return SizedBox(
      key: const ValueKey('cyber-status-cloud'),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.cloud, size: size * 0.88, color: baseColor),
          if (status == CyberCloudLinkStatus.connecting)
            Positioned(
              right: -2,
              bottom: -2,
              child: CyberStatusIconSpin(size: size * 0.48),
            ),
          if (status == CyberCloudLinkStatus.failed)
            Positioned(
              right: -3,
              bottom: -3,
              child: Icon(
                Icons.cancel,
                size: size * 0.48,
                color: const Color(0xFFE53935),
              ),
            ),
        ],
      ),
    );
  }
}
