import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/presentation/home_status_icon_spin.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';

/// Top-right Home camera link icon (stacked Material glyphs).
class HomeCameraStatusIcon extends StatelessWidget {
  const HomeCameraStatusIcon({
    super.key,
    required this.status,
    this.size = 28,
  });

  final IpCameraUiStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final baseColor = switch (status.phase) {
      IpCameraUiPhase.connected => Colors.white,
      IpCameraUiPhase.connecting => Colors.white70,
      IpCameraUiPhase.failed => Colors.white54,
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.videocam, size: size * 0.95, color: baseColor),
          if (status.phase == IpCameraUiPhase.connecting)
            Positioned(
              right: -2,
              bottom: -2,
              child: HomeStatusIconSpin(size: size * 0.48),
            ),
          if (status.phase == IpCameraUiPhase.failed)
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
