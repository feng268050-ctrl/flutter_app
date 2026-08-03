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

/// Fade transitions for named routes (Home → Monitor / Settings / …).
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

/// Forward (enter) fade duration for [buildAppPageRoute].
const Duration kAppPageEnterDuration = Duration(milliseconds: 280);

/// Reverse (pop) fade duration for [buildAppPageRoute].
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
