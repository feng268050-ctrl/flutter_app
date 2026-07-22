import 'package:cyber_ui/src/icons/cyber_camera_link_status.dart';
import 'package:cyber_ui/src/icons/cyber_status_icon_spin.dart';
import 'package:flutter/material.dart';

/// Status-bar camera link icon (stacked Material glyphs).
class CyberCameraStatusIcon extends StatelessWidget {
  const CyberCameraStatusIcon({
    super.key,
    required this.status,
    this.size = 28,
  });

  final CyberCameraLinkStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final baseColor = switch (status) {
      CyberCameraLinkStatus.connected => Colors.white,
      CyberCameraLinkStatus.connecting => Colors.white70,
      CyberCameraLinkStatus.failed => Colors.white54,
    };

    return SizedBox(
      key: const ValueKey('cyber-status-camera'),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.videocam, size: size * 0.95, color: baseColor),
          if (status == CyberCameraLinkStatus.connecting)
            Positioned(
              right: -2,
              bottom: -2,
              child: CyberStatusIconSpin(size: size * 0.48),
            ),
          if (status == CyberCameraLinkStatus.failed)
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
