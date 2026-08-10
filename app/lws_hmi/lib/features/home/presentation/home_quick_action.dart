import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';

/// Design tokens from lws-ui `home_quick_action_*` / `home_stat_card_corner_radius`.
const double kHomeQuickActionCorner = 18;
const double kHomeQuickActionLabelMarginTop = 10;

/// Press: scale 1.0 → [CyberPressFeedback.scalePressed] over 90ms, then settle.
const double kHomeQaPressScale = CyberPressFeedback.scalePressed;
const int kHomeQaPressMs = 90; // keep in sync with CyberPressFeedback.pressIn
const int kHomeQaPressHoldMs = 30;

/// Caption reference used to size all home quick-action labels equally.
const String kHomeQuickActionLabelSizeRef = 'Settings';

/// lws-ui `home_quick_action_label_text` ColorStateList.
const Color _kLabelIdle = Color(0xFFFFFFFF);
const Color _kLabelPressed = Color(0xB3FFFFFF);

/// Called after press settle. Return the [Navigator] push [Future] when
/// navigating so the tile stays at press scale until the route pops.
typedef HomeQuickActionCallback = FutureOr<void> Function();

/// Font size so [kHomeQuickActionLabelSizeRef] fits [cardWidth] with equal
/// side inset (~11% each side) so the caption is not clipped.
///
/// Pass the same [textScaler] that will paint the caption (use
/// [HmiTextScale.quickActionTextScalerOf]) so fit is not undone by a second
/// MediaQuery scale.
double homeQuickActionLabelFontSize(
  double cardWidth, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
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
      textScaler: textScaler,
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
/// - Card scales about its center (1.0 → [kHomeQaPressScale]) on press in
///   performance mode; Balanced keeps scale at 1.0 and only paints the gray
///   overlay (same press language as [CyberPressInkSplash] buttons).
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
    // Clamp reading scale (max 1.05) for fit + paint — avoid double bump.
    final qaScaler = HmiTextScale.quickActionTextScalerOf(context);
    final fontSize = widget.labelFontSize ??
        homeQuickActionLabelFontSize(
          widget.cardWidth,
          textScaler: qaScaler,
        );
    // Balanced: Theme uses CyberPressInkSplash — skip QA scale, overlay only.
    final scaleOnPress = !MediaQuery.disableAnimationsOf(context) &&
        !identical(
          Theme.of(context).splashFactory,
          CyberPressInkSplash.splashFactory,
        );

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
          final scale =
              scaleOnPress ? lerpDouble(1.0, kHomeQaPressScale, t)! : 1.0;
          final labelColor = Color.lerp(_kLabelIdle, _kLabelPressed, t)!;

          Widget card = SizedBox(
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
                    // Home QA only: 30% white (buttons use buttonRim 70%).
                    outlineStyle: CyberPanelOutlineStyle.uniform,
                    borderWidth: 1,
                    borderColor: CyberColors.homeQuickActionRim,
                    child: widget.child,
                  ),
                  // Press: Home-QA gray overlay (same token as buttons).
                  IgnorePointer(
                    child: ColoredBox(
                      color: CyberPressFeedback.overlayAt(t),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (scaleOnPress) {
            card = Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: card,
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              card,
              SizedBox(height: widget.labelMarginTop),
              SizedBox(
                width: captionWidth,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: qaScaler),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
