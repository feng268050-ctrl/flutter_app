import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Design tokens from lws-ui `home_quick_action_*` / `home_stat_card_corner_radius`.
const double kHomeQuickActionCorner = 18;
const double kHomeQuickActionLabelMarginTop = 10;

/// Press: scale 1.0 → 0.94 over 90ms, then ~30ms settle before activate.
const double kHomeQaPressScale = 0.94;
const int kHomeQaPressMs = 90;
const int kHomeQaPressHoldMs = 30;

/// Caption reference used to size all home quick-action labels equally.
const String kHomeQuickActionLabelSizeRef = 'Settings';

/// lws-ui `home_quick_action_label_text` ColorStateList.
const Color _kLabelIdle = Color(0xFFFFFFFF);
const Color _kLabelPressed = Color(0xB3FFFFFF);

/// Semi-transparent dark press overlay on the glass card.
const Color _kPressOverlay = Color(0x66000000);

/// Called after press settle. Return the [Navigator] push [Future] when
/// navigating so the tile stays at press scale until the route pops.
typedef HomeQuickActionCallback = FutureOr<void> Function();

/// Font size so [kHomeQuickActionLabelSizeRef] fits [cardWidth] with equal
/// side inset (~11% each side) so the caption is not clipped.
double homeQuickActionLabelFontSize(double cardWidth) {
  const weight = FontWeight.w500;
  final targetWidth = cardWidth * 0.78;
  var lo = 12.0;
  var hi = 64.0;
  for (var i = 0; i < 14; i++) {
    final mid = (lo + hi) / 2;
    final probe = TextPainter(
      text: TextSpan(
        text: kHomeQuickActionLabelSizeRef,
        style: TextStyle(fontSize: mid, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (probe.width > targetWidth) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return lo;
}

/// Home quick-action tile — Flutter stand-in for lws-ui
/// `FrostQuickActionEntry` + nested `FrostCardView`.
///
/// Architecture:
/// - Outer entry is the press target (card + caption).
/// - Glass [CyberCard] is appearance only (no own gestures).
/// - Card scales about its center (1.0 → [kHomeQaPressScale]) on press,
///   with a semi-transparent dark overlay (no Material ink ripple).
///
/// Not the looping Quick/Engineer WebP halo — those are separate assets.
class HomeQuickAction extends StatefulWidget {
  const HomeQuickAction({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.label,
    required this.onPressed,
    required this.child,
    this.labelWidth,
    this.labelFontSize,
    this.cornerRadius = kHomeQuickActionCorner,
    this.labelMarginTop = kHomeQuickActionLabelMarginTop,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.blurIntensity = CyberBlurIntensity.extreme,
    this.blurTint = CyberBlurTint.warm,
    this.clickSoundEnabled = true,
  });

  final double cardWidth;
  final double cardHeight;
  final String label;
  final HomeQuickActionCallback onPressed;
  final Widget child;

  /// Defaults to [cardWidth] (square tiles). Wide AI Vision passes its card width.
  final double? labelWidth;

  /// When null, sizes so [kHomeQuickActionLabelSizeRef] matches [cardWidth].
  final double? labelFontSize;
  final double cornerRadius;
  final double labelMarginTop;

  final CyberBlurSampleMode sampleMode;
  final CyberBlurIntensity blurIntensity;
  final CyberBlurTint blurTint;
  final bool clickSoundEnabled;

  @override
  State<HomeQuickAction> createState() => _HomeQuickActionState();
}

class _HomeQuickActionState extends State<HomeQuickAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressCurve;

  /// Guards overlapping activate / cancel.
  int _gestureEpoch = 0;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kHomeQaPressMs),
    );
    _pressCurve = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _activate(int epoch) async {
    if (widget.clickSoundEnabled) {
      CyberClickSoundRegistry.playClick();
    }

    // Finish press if the finger lifted early.
    if (_pressController.status != AnimationStatus.completed) {
      await _pressController.forward();
    }
    if (!mounted || epoch != _gestureEpoch) {
      return;
    }

    await Future<void>.delayed(
      const Duration(milliseconds: kHomeQaPressHoldMs),
    );
    if (!mounted || epoch != _gestureEpoch) {
      return;
    }

    try {
      await widget.onPressed();
    } finally {
      if (mounted && epoch == _gestureEpoch) {
        await _pressController.reverse();
      }
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _gestureEpoch++;
    _pressController.forward();
  }

  void _handleTapCancel() {
    _gestureEpoch++;
    _pressController.reverse();
  }

  void _handleTap() {
    final epoch = _gestureEpoch;
    unawaited(_activate(epoch));
  }

  @override
  Widget build(BuildContext context) {
    final captionWidth = widget.labelWidth ?? widget.cardWidth;
    final radius = BorderRadius.circular(widget.cornerRadius);
    final fontSize =
        widget.labelFontSize ?? homeQuickActionLabelFontSize(widget.cardWidth);

    // Outer entry = press target (card + caption), like FrostQuickActionEntry.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _pressCurve,
        builder: (context, child) {
          final t = _pressCurve.value;
          final scale = lerpDouble(1.0, kHomeQaPressScale, t)!;
          final labelColor = Color.lerp(_kLabelIdle, _kLabelPressed, t)!;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: SizedBox(
                  width: widget.cardWidth,
                  height: widget.cardHeight,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Appearance only — CyberCard does not own gestures.
                        CyberCard(
                          width: widget.cardWidth,
                          height: widget.cardHeight,
                          sampleMode: widget.sampleMode,
                          intensity: widget.blurIntensity,
                          blurTint: widget.blurTint,
                          borderRadius: radius,
                          child: widget.child,
                        ),
                        // Press: semi-transparent dark overlay.
                        IgnorePointer(
                          child: ColoredBox(
                            color: Color.lerp(
                              const Color(0x00000000),
                              _kPressOverlay,
                              t,
                            )!,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: widget.labelMarginTop),
              SizedBox(
                width: captionWidth,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
