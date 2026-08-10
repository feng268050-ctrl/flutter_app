import 'package:cyber_ui/src/widgets/cyber_press_feedback.dart';
import 'package:flutter/material.dart';

/// Theme / [InkWell] splash that paints a flat press dim (Home QA grayscale)
/// instead of an expanding ripple.
///
/// Use as [ThemeData.splashFactory] under Balanced / reduced-motion so list
/// rows, tiles, and other Material ink targets share one press language.
final class CyberPressInkSplash extends InteractiveInkFeature {
  CyberPressInkSplash({
    required MaterialInkController controller,
    required super.referenceBox,
    required TextDirection textDirection,
    required Color color,
    VoidCallback? onRemoved,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
  })  : _textDirection = textDirection,
        _borderRadius = borderRadius ?? BorderRadius.zero,
        _customBorder = customBorder,
        _rectCallback = rectCallback,
        _clipCallback = _clipFor(containedInkWell, rectCallback),
        super(
          controller: controller,
          color: color,
          onRemoved: onRemoved,
        ) {
    _controller =
        AnimationController(duration: CyberPressFeedback.pressIn, vsync: controller.vsync)
          ..addListener(controller.markNeedsPaint)
          ..forward();
    controller.addInkFeature(this);
  }

  /// [ThemeData.splashFactory] / [InkWell.splashFactory] token.
  static const InteractiveInkFeatureFactory splashFactory =
      _CyberPressInkSplashFactory();

  final TextDirection _textDirection;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final RectCallback? _rectCallback;
  final RectCallback? _clipCallback;

  late final AnimationController _controller;

  static RectCallback? _clipFor(bool contained, RectCallback? rectCallback) {
    if (rectCallback != null) {
      return rectCallback;
    }
    if (contained) {
      return null; // clip to referenceBox in paint
    }
    return null;
  }

  void _fadeOut() {
    _controller
        .animateTo(0, duration: CyberPressFeedback.pressIn)
        .whenComplete(dispose);
  }

  @override
  void confirm() {
    _fadeOut();
  }

  @override
  void cancel() {
    _fadeOut();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final opacity = _controller.value;
    if (opacity <= 0) {
      return;
    }
    // Always Home-QA gray — ignore [color] so Theme splashColor cannot wash it.
    final paint = Paint()
      ..color = CyberPressFeedback.overlay.withOpacity(
        CyberPressFeedback.overlay.opacity * opacity,
      );

    final rect = _rectCallback?.call() ?? Offset.zero & referenceBox.size;

    void drawPaint() {
      if (_customBorder != null) {
        canvas.drawPath(
          _customBorder!.getOuterPath(rect, textDirection: _textDirection),
          paint,
        );
        return;
      }
      if (_borderRadius != BorderRadius.zero) {
        canvas.drawRRect(_borderRadius.toRRect(rect), paint);
        return;
      }
      canvas.drawRect(rect, paint);
    }

    canvas.save();
    canvas.transform(transform.storage);
    if (_clipCallback != null) {
      canvas.clipRect(_clipCallback!());
    } else if (_customBorder == null && _borderRadius == BorderRadius.zero) {
      // Contained ink wells without an explicit rect still clip to the box.
      canvas.clipRect(Offset.zero & referenceBox.size);
    }
    drawPaint();
    canvas.restore();
  }
}

final class _CyberPressInkSplashFactory extends InteractiveInkFeatureFactory {
  const _CyberPressInkSplashFactory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return CyberPressInkSplash(
      controller: controller,
      referenceBox: referenceBox,
      textDirection: textDirection,
      color: color,
      onRemoved: onRemoved,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
    );
  }
}
