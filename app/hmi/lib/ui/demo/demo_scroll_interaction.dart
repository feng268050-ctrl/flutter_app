import 'package:flutter/material.dart';

/// Shared by Demo ListView sections: ignore Switch toggles while scrolling.
class DemoScrollInteraction extends InheritedWidget {
  const DemoScrollInteraction({
    super.key,
    required this.scrolling,
    required super.child,
  });

  final bool scrolling;

  static bool isScrollingOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DemoScrollInteraction>();
    return scope?.scrolling ?? false;
  }

  @override
  bool updateShouldNotify(DemoScrollInteraction oldWidget) =>
      scrolling != oldWidget.scrolling;
}
