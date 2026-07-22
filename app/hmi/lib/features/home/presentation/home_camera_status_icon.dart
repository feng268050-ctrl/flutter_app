import 'package:flutter/material.dart';
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
          Icon(Icons.videocam, size: size * 0.92, color: baseColor),
          if (status.phase == IpCameraUiPhase.connecting)
            Positioned(
              right: -2,
              bottom: -2,
              child: _SpinningSync(size: size * 0.42),
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

class _SpinningSync extends StatefulWidget {
  const _SpinningSync({required this.size});

  final double size;

  @override
  State<_SpinningSync> createState() => _SpinningSyncState();
}

class _SpinningSyncState extends State<_SpinningSync>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(
        Icons.sync,
        size: widget.size,
        color: Colors.lightBlueAccent,
      ),
    );
  }
}
