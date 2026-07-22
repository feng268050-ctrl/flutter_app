import 'dart:math' as math;

/// Pure slider geometry / long-press-drag helpers (lws-ui `FrostControlLogic`
/// + `FrostSliderCenterSnap` parity).
abstract final class CyberSliderLogic {
  static const longPressThresholdMs = 200;
  static const thumbExpandDurationMs = 150;
  static const thumbDragScale = 1.3;
  static const thumbSize = 33.0;
  static const trackHeight = 12.0;
  static const trackCornerRadius = 8.0;
  static const touchHeight = 33.0;
  static const minTouchHalfExtent = 24.0;
  static const centerSnapThreshold = 3;
  static const centerSnapDwellMs = 100;
  static const snapEscapeDistance = 12.0;
  static const thumbDragOverflow = 8.0;

  static double fractionFromValue(double value, double min, double max) {
    if (max == min) {
      return 0;
    }
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  static double valueFromFraction(double fraction, double min, double max) {
    if (max == min) {
      return min;
    }
    final v = min + fraction.clamp(0.0, 1.0) * (max - min);
    return v.roundToDouble().clamp(min, max);
  }

  static double travelPx(double trackWidthPx, double thumbSizePx) =>
      math.max(0.0, trackWidthPx - thumbSizePx);

  static double thumbCenterX(
    double fraction,
    double trackWidthPx,
    double thumbSizePx, {
    double trackStartX = 0,
  }) {
    final travel = travelPx(trackWidthPx, thumbSizePx);
    if (travel <= 0) {
      return trackStartX + trackWidthPx / 2;
    }
    return trackStartX + thumbSizePx / 2 + travel * fraction.clamp(0.0, 1.0);
  }

  static double fractionFromDelta({
    required double restingFraction,
    required double activationX,
    required double currentX,
    required double travelPx,
  }) {
    if (travelPx <= 0) {
      return restingFraction.clamp(0.0, 1.0);
    }
    final deltaFraction = (currentX - activationX) / travelPx;
    return (restingFraction + deltaFraction).clamp(0.0, 1.0);
  }

  static ({double left, double top, double right, double bottom}) thumbHitRect({
    required double thumbCenterX,
    required double touchHeightPx,
    required double thumbRadiusPx,
    double minTouchHalfExtentPx = minTouchHalfExtent,
  }) {
    final half = math.max(thumbRadiusPx, minTouchHalfExtentPx);
    final centerY = touchHeightPx / 2;
    return (
      left: thumbCenterX - half,
      top: centerY - half,
      right: thumbCenterX + half,
      bottom: centerY + half,
    );
  }

  static bool hitRectContains(
    double x,
    double y,
    ({double left, double top, double right, double bottom}) rect,
  ) =>
      x >= rect.left &&
      x <= rect.right &&
      y >= rect.top &&
      y <= rect.bottom;

  static CyberSliderCenterSnapConfig? centerSnapConfig({
    required double min,
    required double max,
    double centerValue = 0,
    int threshold = centerSnapThreshold,
    double escapeDistancePx = snapEscapeDistance,
    int dwellMs = centerSnapDwellMs,
  }) {
    if (max == min || min >= centerValue || max <= centerValue) {
      return null;
    }
    return CyberSliderCenterSnapConfig(
      centerValue: centerValue,
      threshold: threshold,
      escapeDistancePx: escapeDistancePx,
      dwellMs: dwellMs,
      centerFraction: (centerValue - min) / (max - min),
    );
  }
}

final class CyberSliderCenterSnapConfig {
  const CyberSliderCenterSnapConfig({
    required this.centerValue,
    required this.threshold,
    required this.escapeDistancePx,
    required this.dwellMs,
    required this.centerFraction,
  });

  final double centerValue;
  final int threshold;
  final double escapeDistancePx;
  final int dwellMs;
  final double centerFraction;
}

final class CyberSliderCenterSnapSession {
  bool isCenterSnapped = false;
  double snapAnchorX = double.nan;
  bool centerSnapSuppressed = false;
  double dragRestingFraction = double.nan;

  void reset(double restingFraction) {
    isCenterSnapped = false;
    snapAnchorX = double.nan;
    centerSnapSuppressed = false;
    dragRestingFraction = restingFraction;
  }

  void clear() {
    isCenterSnapped = false;
    snapAnchorX = double.nan;
    centerSnapSuppressed = false;
    dragRestingFraction = double.nan;
  }
}

final class CyberSliderDragResolveResult {
  const CyberSliderDragResolveResult({
    required this.fraction,
    required this.value,
    required this.isCenterSnapped,
    this.reanchorActivationX,
  });

  final double fraction;
  final double value;
  final bool isCenterSnapped;
  final double? reanchorActivationX;
}

CyberSliderDragResolveResult cyberSliderResolveDragValue({
  required CyberSliderCenterSnapConfig? snapConfig,
  required CyberSliderCenterSnapSession snapSession,
  required double min,
  required double max,
  required double travelPx,
  required double activationX,
  required double currentX,
}) {
  final restingFraction = snapSession.dragRestingFraction;
  final rawFraction = CyberSliderLogic.fractionFromDelta(
    restingFraction: restingFraction,
    activationX: activationX,
    currentX: currentX,
    travelPx: travelPx,
  );
  final rawValue = CyberSliderLogic.valueFromFraction(rawFraction, min, max);

  if (snapConfig == null) {
    snapSession.isCenterSnapped = false;
    return CyberSliderDragResolveResult(
      fraction: rawFraction,
      value: rawValue,
      isCenterSnapped: false,
    );
  }

  if (snapSession.isCenterSnapped) {
    final escaped =
        (currentX - snapSession.snapAnchorX).abs() > snapConfig.escapeDistancePx;
    if (escaped) {
      snapSession.isCenterSnapped = false;
      snapSession.centerSnapSuppressed = true;
      final escapedFraction = CyberSliderLogic.fractionFromDelta(
        restingFraction: snapConfig.centerFraction,
        activationX: snapSession.snapAnchorX,
        currentX: currentX,
        travelPx: travelPx,
      );
      final escapedValue =
          CyberSliderLogic.valueFromFraction(escapedFraction, min, max);
      snapSession.dragRestingFraction = escapedFraction;
      return CyberSliderDragResolveResult(
        fraction: escapedFraction,
        value: escapedValue,
        isCenterSnapped: false,
        reanchorActivationX: currentX,
      );
    }
    return CyberSliderDragResolveResult(
      fraction: snapConfig.centerFraction,
      value: snapConfig.centerValue,
      isCenterSnapped: true,
    );
  }

  if (snapSession.centerSnapSuppressed &&
      (rawValue - snapConfig.centerValue).abs() > snapConfig.threshold) {
    snapSession.centerSnapSuppressed = false;
  }

  if (!snapSession.centerSnapSuppressed &&
      (rawValue - snapConfig.centerValue).abs() <= snapConfig.threshold) {
    snapSession.isCenterSnapped = true;
    snapSession.snapAnchorX = currentX;
    return CyberSliderDragResolveResult(
      fraction: snapConfig.centerFraction,
      value: snapConfig.centerValue,
      isCenterSnapped: true,
    );
  }

  return CyberSliderDragResolveResult(
    fraction: rawFraction,
    value: rawValue,
    isCenterSnapped: false,
  );
}
