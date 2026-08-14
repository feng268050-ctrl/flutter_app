import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_slider_logic.dart';

/// Core progress slider with Frost long-press anti-mis-touch (default ON).
///
/// Interaction (lws-ui `FrostSlider` / `frostSliderLongPressDragGesture`):
/// 1. Pointer must land on the thumb hit target (not the bare track).
/// 2. Hold ~200ms without moving past touch slop → thumb expands + click,
///    and value is armed immediately (expand animation does not delay drag).
/// 3. Drag updates by delta from the arm point (does not jump to finger on arm).
/// 4. Ranges spanning 0 get center snap (±3 units, 12px escape).
class CyberSlider extends StatefulWidget {
  const CyberSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.enabled = true,
    this.divisions,
    this.showTickMarks = false,
    this.tapToSelect = false,
    this.longPressDragEnabled = true,
    this.showDragValueLabel = false,
    this.dragValueLabelBuilder,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final bool enabled;
  final int? divisions;

  /// Shows evenly-spaced ticks when [divisions] is set.
  final bool showTickMarks;

  /// Lets a tap on the track select the nearest discrete value immediately.
  ///
  /// This is intended for short, discrete choice sliders. It has no effect
  /// unless [divisions] is set.
  final bool tapToSelect;

  /// When true (default), require long-press on thumb before dragging.
  final bool longPressDragEnabled;

  /// When true, show a floating value label above the thumb while dragging.
  final bool showDragValueLabel;

  /// Formats [showDragValueLabel] text; defaults to rounded integer.
  final String Function(double value)? dragValueLabelBuilder;

  @override
  State<CyberSlider> createState() => _CyberSliderState();
}

class _CyberSliderState extends State<CyberSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;
  Timer? _longPressTimer;

  bool _thumbExpanded = false;
  bool _valueArmed = false;
  double? _dragFraction;
  double _restingFraction = 0;
  double _activationX = 0;
  double _downX = 0;
  double _lastX = 0;
  int? _activePointer;
  bool _startedExpand = false;

  final CyberSliderCenterSnapSession _snapSession =
      CyberSliderCenterSnapSession();

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: CyberSliderLogic.thumbExpandDurationMs,
      ),
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    _expand.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _resetGesture({required bool cancelled}) {
    final endedArmed = _startedExpand;
    final endValue = _snapValue(_displayValue);
    _cancelTimers();
    if (endedArmed) {
      CyberClickSoundRegistry.playClick();
      if (!cancelled) {
        widget.onChangeEnd?.call(endValue);
      }
    }
    _activePointer = null;
    _startedExpand = false;
    _thumbExpanded = false;
    _valueArmed = false;
    _dragFraction = null;
    _snapSession.clear();
    _expand.reverse();
    if (mounted) {
      setState(() {});
    }
  }

  double get _displayFraction {
    if (_valueArmed && _dragFraction != null) {
      return _dragFraction!;
    }
    return CyberSliderLogic.fractionFromValue(
      widget.value,
      widget.min,
      widget.max,
    );
  }

  double get _displayValue => CyberSliderLogic.valueFromFraction(
        _displayFraction,
        widget.min,
        widget.max,
      );

  double _snapValue(double value) => CyberSliderLogic.snapValueToDivisions(
        value: value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
      );

  double _snapFraction(double fraction) => CyberSliderLogic.fractionFromValue(
        _snapValue(
          CyberSliderLogic.valueFromFraction(
            fraction,
            widget.min,
            widget.max,
          ),
        ),
        widget.min,
        widget.max,
      );

  void _applyArmedDrag(double currentX, double travel) {
    if (!_valueArmed) {
      return;
    }
    final snapConfig = CyberSliderLogic.centerSnapConfig(
      min: widget.min,
      max: widget.max,
    );
    final result = cyberSliderResolveDragValue(
      snapConfig: snapConfig,
      snapSession: _snapSession,
      min: widget.min,
      max: widget.max,
      travelPx: travel,
      activationX: _activationX,
      currentX: currentX,
    );
    if (result.reanchorActivationX != null) {
      _activationX = result.reanchorActivationX!;
    }
    _dragFraction = _snapFraction(result.fraction);
    widget.onChanged(_snapValue(result.value));
    setState(() {});
  }

  void _onPointerDown(
    PointerDownEvent event,
    double trackWidth,
    double overflow,
  ) {
    if (!widget.enabled || _activePointer != null) {
      return;
    }
    final thumbPx = CyberSliderLogic.thumbSize;
    final trackStart = overflow;
    final resting = CyberSliderLogic.fractionFromValue(
      widget.value,
      widget.min,
      widget.max,
    );
    final thumbCx = CyberSliderLogic.thumbCenterX(
      resting,
      trackWidth,
      thumbPx,
      trackStartX: trackStart,
    );
    final touchH = CyberSliderLogic.touchHeight;
    final hit = CyberSliderLogic.thumbHitRect(
      thumbCenterX: thumbCx,
      touchHeightPx: touchH,
      thumbRadiusPx: thumbPx / 2,
    );
    if (!CyberSliderLogic.hitRectContains(
      event.localPosition.dx,
      event.localPosition.dy,
      hit,
    )) {
      if (widget.tapToSelect && widget.divisions != null) {
        final travel = CyberSliderLogic.travelPx(trackWidth, thumbPx);
        final fraction = travel <= 0
            ? resting
            : ((event.localPosition.dx - trackStart - thumbPx / 2) / travel)
                .clamp(0.0, 1.0);
        final value = _snapValue(
          CyberSliderLogic.valueFromFraction(
            fraction,
            widget.min,
            widget.max,
          ),
        );
        widget.onChanged(value);
        widget.onChangeEnd?.call(value);
        CyberClickSoundRegistry.playClick();
      }
      return;
    }

    _activePointer = event.pointer;
    _downX = event.localPosition.dx;
    _lastX = _downX;
    _restingFraction = resting;
    _dragFraction = null;
    _valueArmed = false;
    _thumbExpanded = false;
    _startedExpand = false;
    _snapSession.clear();

    if (!widget.longPressDragEnabled) {
      _startedExpand = true;
      _thumbExpanded = true;
      _valueArmed = true;
      _activationX = _lastX;
      _dragFraction = resting;
      _snapSession.reset(resting);
      _expand.forward();
      CyberClickSoundRegistry.playClick();
      setState(() {});
      return;
    }

    _longPressTimer = Timer(
      const Duration(milliseconds: CyberSliderLogic.longPressThresholdMs),
      () {
        if (_activePointer == null) {
          return;
        }
        _startedExpand = true;
        _thumbExpanded = true;
        _valueArmed = true;
        _activationX = _lastX;
        _expand.forward();
        CyberClickSoundRegistry.playClick();
        _snapSession.reset(_restingFraction);
        _dragFraction = _restingFraction;
        setState(() {});
      },
    );
  }

  void _onPointerMove(PointerMoveEvent event, double travel) {
    if (_activePointer != event.pointer) {
      return;
    }
    final x = event.localPosition.dx;
    _lastX = x;
    if (!_thumbExpanded) {
      if ((x - _downX).abs() > kTouchSlop) {
        _cancelTimers();
        _activePointer = null;
        return;
      }
      return;
    }
    if (_valueArmed) {
      _applyArmedDrag(x, travel);
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _resetGesture(cancelled: false);
  }

  void _onPointerCancel(PointerEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _resetGesture(cancelled: true);
  }

  @override
  Widget build(BuildContext context) {
    final overflow = CyberSliderLogic.thumbDragOverflow;
    // Resting thumb height only — drag bubble paints above via [Clip.none]
    // (SettingsPanel frosts stay clipped; content layer allows overflow).
    final touchH = CyberSliderLogic.touchHeight;

    return SizedBox(
      height: touchH,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final trackWidth = (width - overflow * 2).clamp(0.0, width);
          final travel = CyberSliderLogic.travelPx(
            trackWidth,
            CyberSliderLogic.thumbSize,
          );
          final fraction = _displayFraction;
          final thumbCx = CyberSliderLogic.thumbCenterX(
            fraction,
            trackWidth,
            CyberSliderLogic.thumbSize,
            trackStartX: overflow,
          );
          final showBubble = widget.showDragValueLabel && _thumbExpanded;
          final label = widget.dragValueLabelBuilder?.call(_displayValue) ??
              '${_displayValue.round()}';

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _onPointerDown(e, trackWidth, overflow),
                onPointerMove: (e) => _onPointerMove(e, travel),
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: AnimatedBuilder(
                  animation: _expand,
                  builder: (context, _) {
                    final scale = 1.0 +
                        (CyberSliderLogic.thumbDragScale - 1.0) * _expand.value;
                    return CustomPaint(
                      size: Size(width, touchH),
                      painter: _CyberSliderPainter(
                        trackStartX: overflow,
                        trackWidth: trackWidth,
                        thumbCenterX: thumbCx,
                        thumbScale: scale,
                        activeColor: CyberColors.buttonPrimaryAccent,
                        inactiveColor: CyberColors.borderMid,
                        thumbColor: CyberColors.textPrimary,
                        divisions:
                            widget.showTickMarks ? widget.divisions : null,
                        activeFraction: fraction,
                      ),
                    );
                  },
                ),
              ),
              if (showBubble)
                Positioned(
                  left: (thumbCx - _CyberSliderDragValueBubble.width / 2)
                      .clamp(0.0, width - _CyberSliderDragValueBubble.width),
                  top: -_CyberSliderDragValueBubble.height -
                      _CyberSliderDragValueBubble.gapBelow,
                  child: _CyberSliderDragValueBubble(label: label),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact value chip above the thumb while dragging.
class _CyberSliderDragValueBubble extends StatelessWidget {
  const _CyberSliderDragValueBubble({required this.label});

  static const width = 48.0;
  static const height = CyberSliderLogic.dragValueBubbleHeight;
  static const gapBelow = CyberSliderLogic.dragValueBubbleGap;

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CyberColors.fillSolidTop,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CyberColors.borderHighlight),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CyberColors.textPrimary,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberSliderPainter extends CustomPainter {
  _CyberSliderPainter({
    required this.trackStartX,
    required this.trackWidth,
    required this.thumbCenterX,
    required this.thumbScale,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    this.divisions,
    required this.activeFraction,
  });

  final double trackStartX;
  final double trackWidth;
  final double thumbCenterX;
  final double thumbScale;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final int? divisions;
  final double activeFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final trackH = CyberSliderLogic.trackHeight;
    final trackTop = (size.height - trackH) / 2;
    final r = Radius.circular(CyberSliderLogic.trackCornerRadius);
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(trackStartX, trackTop, trackWidth, trackH),
      r,
    );
    canvas.drawRRect(trackRect, Paint()..color = inactiveColor);

    final activeW = (thumbCenterX - trackStartX).clamp(0.0, trackWidth);
    if (activeW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(trackStartX, trackTop, activeW, trackH),
          r,
        ),
        Paint()..color = activeColor,
      );
    }

    final tickCount = divisions;
    if (tickCount != null && tickCount > 0) {
      final tickPaint = Paint()..isAntiAlias = true;
      final travel = CyberSliderLogic.travelPx(
        trackWidth,
        CyberSliderLogic.thumbSize,
      );
      for (var i = 0; i <= tickCount; i++) {
        final tickFraction = i / tickCount;
        final tickX = trackStartX +
            CyberSliderLogic.thumbSize / 2 +
            travel * tickFraction;
        tickPaint.color =
            tickFraction <= activeFraction ? activeColor : inactiveColor;
        canvas.drawCircle(Offset(tickX, size.height / 2), 3, tickPaint);
      }
    }

    final radius = (CyberSliderLogic.thumbSize / 2) * thumbScale;
    canvas.drawCircle(
      Offset(thumbCenterX, size.height / 2),
      radius,
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberSliderPainter oldDelegate) {
    return trackStartX != oldDelegate.trackStartX ||
        trackWidth != oldDelegate.trackWidth ||
        thumbCenterX != oldDelegate.thumbCenterX ||
        thumbScale != oldDelegate.thumbScale ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor ||
        thumbColor != oldDelegate.thumbColor ||
        divisions != oldDelegate.divisions ||
        activeFraction != oldDelegate.activeFraction;
  }
}
