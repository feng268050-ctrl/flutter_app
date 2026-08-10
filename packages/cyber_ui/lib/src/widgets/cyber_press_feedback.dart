import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:flutter/material.dart';

/// Shared press dim / scale — Home Monitor·Settings QA and product chrome.
///
/// Matches lws-ui / [HomeQuickAction]: semi-transparent dark overlay
/// (`0x66000000`), optional scale 1→0.94 over 90ms. No Material ink ripple.
abstract final class CyberPressFeedback {
  /// Press overlay at full press (ARGB). Same as Home quick-action tiles.
  static const Color overlay = Color(0x66000000);

  /// Transparent → [overlay] lerp start.
  static const Color overlayIdle = Color(0x00000000);

  static const double scalePressed = 0.94;
  static const Duration pressIn = Duration(milliseconds: 90);
  static const Duration pressHold = Duration(milliseconds: 30);

  static Color overlayAt(double t) =>
      Color.lerp(overlayIdle, overlay, t.clamp(0.0, 1.0))!;

  static double scaleAt(double t) =>
      lerpDouble(1.0, scalePressed, t.clamp(0.0, 1.0))!;
}

/// Gesture target with Home-QA press chrome (overlay ± scale), no ink ripple.
final class CyberPressable extends StatefulWidget {
  const CyberPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius,
    this.scaleOnPress = true,
    this.clickSoundEnabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final FutureOr<void> Function()? onPressed;
  final BorderRadius? borderRadius;
  final bool scaleOnPress;
  final bool clickSoundEnabled;
  final HitTestBehavior behavior;

  @override
  State<CyberPressable> createState() => _CyberPressableState();
}

class _CyberPressableState extends State<CyberPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _curve;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: CyberPressFeedback.pressIn,
    );
    _curve = CurvedAnimation(
      parent: _press,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _activate(int epoch) async {
    if (widget.onPressed == null) {
      return;
    }
    if (widget.clickSoundEnabled) {
      CyberClickSoundRegistry.playClick();
    }
    if (_press.status != AnimationStatus.completed) {
      await _press.forward();
    }
    if (!mounted || epoch != _epoch) {
      return;
    }
    await Future<void>.delayed(CyberPressFeedback.pressHold);
    if (!mounted || epoch != _epoch) {
      return;
    }
    try {
      await widget.onPressed!();
    } finally {
      if (mounted && epoch == _epoch) {
        await _press.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onPressed == null
          ? null
          : (_) {
              _epoch++;
              _press.forward();
            },
      onTapCancel: widget.onPressed == null
          ? null
          : () {
              _epoch++;
              _press.reverse();
            },
      onTap: widget.onPressed == null
          ? null
          : () {
              final epoch = _epoch;
              unawaited(_activate(epoch));
            },
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value;
          Widget content = Stack(
            fit: StackFit.passthrough,
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ColoredBox(
                      color: CyberPressFeedback.overlayAt(t),
                    ),
                  ),
                ),
              ),
            ],
          );
          if (widget.scaleOnPress) {
            content = Transform.scale(
              scale: CyberPressFeedback.scaleAt(t),
              alignment: Alignment.center,
              child: content,
            );
          }
          return content;
        },
        child: widget.child,
      ),
    );
  }
}
