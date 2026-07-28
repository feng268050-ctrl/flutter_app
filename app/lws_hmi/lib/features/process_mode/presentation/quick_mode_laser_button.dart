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
    if (widget.busy) {
      widget.onBlocked(LaserEnableBlockReason.busy.message);
      return;
    }
    if (!_QuickLaserTrapezoid.contains(
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
    return SizedBox(
      key: const ValueKey('quick-mode-laser-enable'),
      width: size.width,
      height: size.height,
      child: Stack(
        // Keep edge shadow inside the 564×223 graphic — no overflow bloom.
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          // Edge shadow behind chrome: covers arc-shoulder voids along the
          // trapezoid rim without changing the WebP button colors.
          // Must IgnorePointer — otherwise the full 564×223 rect steals taps
          // above the trapezoid (More Status sits in that overlap band).
          IgnorePointer(
            child: CustomPaint(
              painter: _LaserTrapezoidRimShadowPainter(scale: scale),
            ),
          ),
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
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
                ],
              ),
            ),
            // Hits + ripple stay trapezoid-clipped so More Status remains tappable.
            ClipPath(
              clipper: const _QuickLaserTrapezoidClipper(),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: _pointerUp,
                onPointerCancel: (_) => _cancelGesture(),
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
            ),
          ],
        ),
    );
  }
}

abstract final class _QuickLaserTrapezoid {
  static const double topWidthRatio =
      ProcessModeDimens.quickLaserTrapezoidTopWidthRatio;
  static const double bottomWidthRatio =
      ProcessModeDimens.quickLaserTrapezoidBottomWidthRatio;
  static const double heightRatio =
      ProcessModeDimens.quickLaserTrapezoidHeightRatio;

  static Path path(Size size) {
    final v = vertices(size);
    return Path()
      ..moveTo(v.topLeft.dx, v.topLeft.dy)
      ..lineTo(v.topRight.dx, v.topRight.dy)
      ..lineTo(v.bottomRight.dx, v.bottomRight.dy)
      ..lineTo(v.bottomLeft.dx, v.bottomLeft.dy)
      ..close();
  }

  static ({
    Offset topLeft,
    Offset topRight,
    Offset bottomRight,
    Offset bottomLeft,
  }) vertices(Size size) {
    final topY = size.height * (1 - heightRatio);
    final topInset = size.width * (1 - topWidthRatio) / 2;
    final bottomInset = size.width * (1 - bottomWidthRatio) / 2;
    return (
      topLeft: Offset(topInset, topY),
      topRight: Offset(size.width - topInset, topY),
      bottomRight: Offset(size.width - bottomInset, size.height),
      bottomLeft: Offset(bottomInset, size.height),
    );
  }

  static bool contains(Offset point, Size size) => path(size).contains(point);

  static double coverRadius(Offset origin, Size size) {
    final v = vertices(size);
    return [v.topLeft, v.topRight, v.bottomRight, v.bottomLeft]
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

/// Edge shadow along the trapezoid rim (top + upper slants only).
///
/// Fills a thin band **outside** the trapezoid path but **inside** the 564×223
/// graphic rect — covers arc-shoulder voids without changing WebP colors or
/// blooming past the button silhouette. Bottom edge stays clean.
final class _LaserTrapezoidRimShadowPainter extends CustomPainter {
  const _LaserTrapezoidRimShadowPainter({required this.scale});

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final v = _QuickLaserTrapezoid.vertices(size);
    final trap = _QuickLaserTrapezoid.path(size);
    final band = ProcessModeDimens.quickLaserRimShadowStroke * scale;
    final blur = ProcessModeDimens.quickLaserRimShadowBlur * scale;

    // Only the exterior of the trapezoid, still inside this graphic.
    final exterior = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(trap, Offset.zero);

    canvas.save();
    canvas.clipPath(exterior);
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height * 0.88));

    // Outer rim path: offset the top + upper slants outward, then evenOdd
    // against the trapezoid → a filled edge band (not a centered stroke that
    // straddles into chrome).
    final outward = band * 0.85;
    final topLeftOut = Offset(v.topLeft.dx - outward * 0.35, v.topLeft.dy - outward);
    final topRightOut =
        Offset(v.topRight.dx + outward * 0.35, v.topRight.dy - outward);
    final leftEnd = Offset.lerp(v.topLeft, v.bottomLeft, 0.55)!;
    final rightEnd = Offset.lerp(v.topRight, v.bottomRight, 0.55)!;
    final leftEndOut = Offset(leftEnd.dx - outward * 0.7, leftEnd.dy);
    final rightEndOut = Offset(rightEnd.dx + outward * 0.7, rightEnd.dy);

    final rimBand = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(leftEndOut.dx, leftEndOut.dy)
      ..lineTo(topLeftOut.dx, topLeftOut.dy)
      ..lineTo(topRightOut.dx, topRightOut.dy)
      ..lineTo(rightEndOut.dx, rightEndOut.dy)
      ..lineTo(rightEnd.dx, rightEnd.dy)
      ..lineTo(v.topRight.dx, v.topRight.dy)
      ..lineTo(v.topLeft.dx, v.topLeft.dy)
      ..lineTo(leftEnd.dx, leftEnd.dy)
      ..close();

    canvas.drawPath(
      rimBand,
      Paint()
        ..color = const Color(0xD9000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LaserTrapezoidRimShadowPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

/// Hold-to-enable radial fill; always clips to the trapezoid (lws-ui overlay).
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
    // Match Android LaserButtonTrapezoidRippleOverlay: clip in draw, not only
    // via outer ClipPath (more reliable for the fill demo range).
    canvas.save();
    canvas.clipPath(_QuickLaserTrapezoid.path(size));

    if (pressed) {
      canvas.drawPath(
        _QuickLaserTrapezoid.path(size),
        Paint()..color = const Color(0x24FFFFFF),
      );
    }
    if (progress > 0) {
      final radius = _QuickLaserTrapezoid.coverRadius(origin, size) * progress;
      canvas.drawCircle(
        origin,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0x70FFFFFF),
              Color(0x30FFFFFF),
            ],
          ).createShader(Rect.fromCircle(center: origin, radius: radius)),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HoldRipplePainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.progress != progress ||
      oldDelegate.pressed != pressed;
}
