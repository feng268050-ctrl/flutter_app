import 'package:flutter/material.dart';

/// Per-row ink clip hints from an enclosing frosted [SettingsGroup]-style card.
///
/// [SettingsPanel] keeps [Clip.none] so overflow chrome (e.g. CyberSlider drag
/// bubbles) can paint past the plate. Material ink must still follow the card
/// corner radius — [SettingsRowFrame] reads this scope and passes
/// [splashBorderRadius] to [InkWell.borderRadius] (ink-only clip).
class SettingsCardInk extends InheritedWidget {
  const SettingsCardInk({
    super.key,
    required this.borderRadius,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final BorderRadius borderRadius;
  final bool isFirst;
  final bool isLast;

  static SettingsCardInk? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsCardInk>();
  }

  /// Corner radii for this row's Material ink (zero for middle rows).
  BorderRadius get splashBorderRadius {
    if (isFirst && isLast) return borderRadius;
    if (!isFirst && !isLast) return BorderRadius.zero;
    return BorderRadius.only(
      topLeft: isFirst ? borderRadius.topLeft : Radius.zero,
      topRight: isFirst ? borderRadius.topRight : Radius.zero,
      bottomLeft: isLast ? borderRadius.bottomLeft : Radius.zero,
      bottomRight: isLast ? borderRadius.bottomRight : Radius.zero,
    );
  }

  @override
  bool updateShouldNotify(SettingsCardInk oldWidget) {
    return borderRadius != oldWidget.borderRadius ||
        isFirst != oldWidget.isFirst ||
        isLast != oldWidget.isLast;
  }
}
