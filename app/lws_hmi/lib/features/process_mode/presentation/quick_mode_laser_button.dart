import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';

/// Quick-mode trapezoid laser button nested in the dashboard's lower opening.
///
/// Closed: hold until the clipped radial ripple fills, then release to confirm.
/// Open: a short press immediately requests End of work.
final class QuickModeLaserButton extends StatefulWidget {
  const QuickModeLaserButton({
    super.key,
    required this.processType,
    required this.laserOpen,
    required this.busy,
    required this.preflight,
    required this.onEnableConfirmed,
    required this.onDisable,
    required this.onBlocked,
  });

  final ProcessType processType;
  final bool laserOpen;
  final bool busy;
  final String? Function() preflight;
  final Future<void> Function() onEnableConfirmed;
  final Future<void> Function() onDisable;
  final ValueChanged<String> onBlocked;

  @override
  State<QuickModeLaserButton> createState() => _QuickModeLaserButtonState();
}

final class _QuickModeLaserButtonState extends State<QuickModeLaserButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: DeviceControlTiming.laserHoldToEnable,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _commitReady = true;
      }
    });

  bool _gestureActive = false;
  bool _commitReady = false;
  Offset _origin = Offset.zero;

  String get _background {
    if (widget.processType.isCleaning) {
      return ProcessModeAssets.laserEnableBtnGreen;
    }
    if (widget.processType == ProcessType.handCutting ||
        widget.processType == ProcessType.cncCutting) {
      return ProcessModeAssets.laserEnableBtnBlue;
    }
    return ProcessModeAssets.laserEnableBtn;
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Size _buttonSize(BuildContext context) {
    final scale =
        ProcessModeDimens.dashboardScaleFor(MediaQuery.sizeOf(context));
    return Size(
      ProcessModeDimens.quickLaserButtonWidth * scale,
      ProcessModeDimens.quickLaserButtonHeight * scale,
    );
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.busy ||
        !_QuickLaserTrapezoid.contains(
          event.localPosition,
          _buttonSize(context),
        )) {
      return;
    }
    _gestureActive = true;
    _commitReady = false;
    _origin = event.localPosition;
    if (widget.laserOpen) {
      setState(() {});
      return;
    }
    final blocked = widget.preflight();
    if (blocked != null) {
      _gestureActive = false;
      widget.onBlocked(blocked);
      return;
    }
    _hold.forward(from: 0);
    setState(() {});
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_gestureActive &&
        !_QuickLaserTrapezoid.contains(
          event.localPosition,
          _buttonSize(context),
        )) {
      _cancelGesture();
    }
  }

  void _pointerUp(PointerUpEvent event) {
    if (!_gestureActive) {
      return;
    }
    _gestureActive = false;
    if (widget.laserOpen) {
      unawaited(widget.onDisable());
      setState(() {});
      return;
    }
    if (_commitReady || _hold.value >= 0.999) {
      _hold.value = 0;
      _commitReady = false;
      unawaited(widget.onEnableConfirmed());
      setState(() {});
      return;
    }
    _reverseRipple();
  }

  void _cancelGesture() {
    if (!_gestureActive && _hold.value == 0) {
      return;
    }
    _gestureActive = false;
    _commitReady = false;
    _reverseRipple();
  }

  void _reverseRipple() {
    final duration = Duration(
      milliseconds:
          (DeviceControlTiming.laserHoldToEnable.inMilliseconds * _hold.value)
              .round(),
    );
    unawaited(_hold.animateBack(0, duration: duration));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scale =
        ProcessModeDimens.dashboardScaleFor(MediaQuery.sizeOf(context));
    final size = _buttonSize(context);
    return AnimatedOpacity(
      opacity: widget.busy ? 0.45 : 1,
      duration: const Duration(milliseconds: 120),
      child: SizedBox(
        key: const ValueKey('quick-mode-laser-enable'),
        width: size.width,
        height: size.height,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerUp,
          onPointerCancel: (_) => _cancelGesture(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black bevels at the dashboard contact are baked into the
              // lws-ui WebP. Do not add a generic Flutter drop shadow: the
              // Android layout only elevates this bitmap-backed view.
              Image.asset(_background, fit: BoxFit.fill),
              Positioned(
                top: 68 * scale,
                left: 0,
                right: 0,
                child: Icon(
                  widget.laserOpen
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  key: const ValueKey('quick-mode-laser-enable-icon'),
                  color: Colors.white,
                  size: ProcessModeDimens.quickLaserButtonIconSize * scale,
                ),
              ),
              Positioned(
                top: 147 * scale,
                left: 0,
                right: 0,
                child: Text(
                  widget.laserOpen ? 'End of work' : 'Laser Enable',
                  key: const ValueKey('quick-mode-laser-enable-label'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize:
                        ProcessModeDimens.quickLaserButtonLabelSize * scale,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ClipPath(
                clipper: const _QuickLaserTrapezoidClipper(),
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => CustomPaint(
                    painter: _HoldRipplePainter(
                      origin: _origin,
                      progress: _hold.value,
                      pressed: _gestureActive && widget.laserOpen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class _QuickLaserTrapezoid {
  static const double topWidthRatio = 0.5;
  static const double bottomWidthRatio = 0.93;
  static const double heightRatio = 0.8;

  static Path path(Size size) {
    final topY = size.height * (1 - heightRatio);
    final topInset = size.width * (1 - topWidthRatio) / 2;
    final bottomInset = size.width * (1 - bottomWidthRatio) / 2;
    return Path()
      ..moveTo(topInset, topY)
      ..lineTo(size.width - topInset, topY)
      ..lineTo(size.width - bottomInset, size.height)
      ..lineTo(bottomInset, size.height)
      ..close();
  }

  static bool contains(Offset point, Size size) => path(size).contains(point);

  static double coverRadius(Offset origin, Size size) {
    final topY = size.height * (1 - heightRatio);
    final topInset = size.width * (1 - topWidthRatio) / 2;
    final bottomInset = size.width * (1 - bottomWidthRatio) / 2;
    final vertices = [
      Offset(topInset, topY),
      Offset(size.width - topInset, topY),
      Offset(size.width - bottomInset, size.height),
      Offset(bottomInset, size.height),
    ];
    return vertices
        .map((point) => (point - origin).distance)
        .fold<double>(0, math.max);
  }
}

final class _QuickLaserTrapezoidClipper extends CustomClipper<Path> {
  const _QuickLaserTrapezoidClipper();

  @override
  Path getClip(Size size) => _QuickLaserTrapezoid.path(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

final class _HoldRipplePainter extends CustomPainter {
  const _HoldRipplePainter({
    required this.origin,
    required this.progress,
    required this.pressed,
  });

  final Offset origin;
  final double progress;
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    if (pressed) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x24FFFFFF),
      );
    }
    if (progress <= 0) {
      return;
    }
    final radius = _QuickLaserTrapezoid.coverRadius(origin, size) * progress;
    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x70FFFFFF),
            const Color(0x30FFFFFF),
          ],
        ).createShader(Rect.fromCircle(center: origin, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _HoldRipplePainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.progress != progress ||
      oldDelegate.pressed != pressed;
}
