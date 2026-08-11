import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/widgets/cyber_press_ink_splash.dart';
import 'package:flutter/material.dart';

/// Shared press dim / scale — Home Monitor·Settings QA and product chrome.
///
/// Matches lws-ui / [HomeQuickAction]: semi-transparent dark overlay
/// (`0x66000000`), optional scale 1→0.94 over 90ms. No Material ink ripple.
abstract final class CyberPressFeedback {
  /// Press overlay at full press (ARGB). Same as Home quick-action tiles.
  static const Color overlay = Color(0x66000000);

  /// Flat fill of the original tile ripple (lws-ui `FrostButtonTileRipple` /
  /// [CyberButtonPressDefaults.defaultRipple]) — full bounds, no expand.
  static const Color tileRipple = Color(0x3DFFFFFF);

  /// Transparent → [overlay] lerp start.
  static const Color overlayIdle = Color(0x00000000);

  static const double scalePressed = 0.94;
  static const Duration pressIn = Duration(milliseconds: 90);
  static const Duration pressHold = Duration(milliseconds: 30);

  static Color overlayAt(double t, [Color? pressed]) =>
      Color.lerp(overlayIdle, pressed ?? overlay, t.clamp(0.0, 1.0))!;

  static double scaleAt(double t) =>
      lerpDouble(1.0, scalePressed, t.clamp(0.0, 1.0))!;
}

/// Gesture target with Home-QA press chrome (overlay ± scale), no ink ripple.
///
/// When [scaleOnPress] is true, Performance mode scales 1→0.94; Balanced
/// (`CyberPressInkSplash` theme / reduce-motion) keeps scale at 1.0 and only
/// paints the gray overlay — same policy as Home quick-action tiles.
///
/// Optional [pressPlate] fades in under the content on press (e.g. a Home-QA
/// [CyberCard] frost) so chrome without an idle under-plate still matches
/// Monitor / Settings / AI Vision press look.
final class CyberPressable extends StatefulWidget {
  const CyberPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius,
    this.overlay,
    this.pressPlate,
    this.scaleOnPress = true,
    this.clickSoundEnabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final FutureOr<void> Function()? onPressed;
  final BorderRadius? borderRadius;

  /// Full-press overlay color. Defaults to [CyberPressFeedback.overlay].
  final Color? overlay;

  /// Drawn under [child] while pressed (opacity follows press progress).
  final Widget? pressPlate;
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
    // Match HomeQuickAction: Balanced (CyberPressInkSplash theme) keeps scale
    // at 1.0 and only paints the gray overlay.
    final scaleOnPress = widget.scaleOnPress &&
        !MediaQuery.disableAnimationsOf(context) &&
        !identical(
          Theme.of(context).splashFactory,
          CyberPressInkSplash.splashFactory,
        );
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
          final plate = widget.pressPlate;
          Widget content = Stack(
            fit: StackFit.passthrough,
            children: [
              if (plate != null && t > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: plate,
                      ),
                    ),
                  ),
                ),
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ColoredBox(
                      color: CyberPressFeedback.overlayAt(
                        t,
                        widget.overlay,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          if (scaleOnPress) {
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
