import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Always use bounce overscroll (phone/tablet feel on eLinux / Linux).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

/// Fade transitions for Home → module named routes (and Material themes).
const PageTransitionsTheme kAppPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _FadePageTransitionsBuilder(),
    TargetPlatform.iOS: _FadePageTransitionsBuilder(),
    TargetPlatform.linux: _FadePageTransitionsBuilder(),
    TargetPlatform.macOS: _FadePageTransitionsBuilder(),
    TargetPlatform.windows: _FadePageTransitionsBuilder(),
    TargetPlatform.fuchsia: _FadePageTransitionsBuilder(),
  },
);

/// Forward (enter) duration for Home fade / in-module slide.
const Duration kAppPageEnterDuration = Duration(milliseconds: 280);

/// Reverse (pop) duration for Home fade / in-module slide.
const Duration kAppPageExitDuration = Duration(milliseconds: 240);

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}

/// Fade in/out for Home → Settings / Monitor / Quick / Engineer / AI Vision.
Route<dynamic> buildAppPageRoute({
  required RouteSettings settings,
  required Widget child,
}) {
  return PageRouteBuilder<dynamic>(
    settings: settings,
    transitionDuration: kAppPageEnterDuration,
    reverseTransitionDuration: kAppPageExitDuration,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

/// Horizontal slide (enter from the right) for in-module navigation.
///
/// Used for Settings sub-pages, Monitor detail/choose flows, Quick→Engineer
/// handoff, etc. Keeps industry L/R Cupertino transitions.
Route<T> buildAppSlideRoute<T>({
  RouteSettings? settings,
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) {
  return CupertinoPageRoute<T>(
    settings: settings,
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}

/// Push [page] with [buildAppSlideRoute] (in-module L/R slide).
Future<T?> pushAppSlidePage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    buildAppSlideRoute<T>(builder: (_) => page),
  );
}
