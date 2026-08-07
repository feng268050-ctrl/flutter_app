import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/load_profile_scope.dart';

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

/// Enter duration under balanced load profile (snap chrome transitions).
Duration appPageEnterDuration(BuildContext? context, {bool? snap}) {
  final effective = snap ??
      (context != null &&
          (LoadProfileScope.maybeOf(context)?.snapPageTransitions ?? false));
  if (effective) {
    return Duration.zero;
  }
  return kAppPageEnterDuration;
}

/// Exit duration under balanced load profile.
Duration appPageExitDuration(BuildContext? context, {bool? snap}) {
  final effective = snap ??
      (context != null &&
          (LoadProfileScope.maybeOf(context)?.snapPageTransitions ?? false));
  if (effective) {
    return Duration.zero;
  }
  return kAppPageExitDuration;
}

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
  BuildContext? context,
  bool? snap,
}) {
  return PageRouteBuilder<dynamic>(
    settings: settings,
    transitionDuration: appPageEnterDuration(context, snap: snap),
    reverseTransitionDuration: appPageExitDuration(context, snap: snap),
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

/// Emit exactly one initial route for [MaterialApp.onGenerateInitialRoutes].
///
/// Flutter's [Navigator.defaultGenerateInitialRoutes] always pushes `/` before
/// any `/foo` path. With [AppRoutes.home] == `/` and startup
/// [AppRoutes.safetyTips] == `/safety-tips`, that mounts Home under Safety Tips
/// and starts Boot Self-Check over the tips screen. Product startup must be a
/// single route only.
List<Route<dynamic>> generateAppInitialRoutes(
  String initialRouteName,
  RouteFactory onGenerateRoute,
) {
  final name =
      initialRouteName.isEmpty ? Navigator.defaultRouteName : initialRouteName;
  final route = onGenerateRoute(RouteSettings(name: name));
  if (route != null) {
    return <Route<dynamic>>[route];
  }
  final fallback = onGenerateRoute(
    const RouteSettings(name: Navigator.defaultRouteName),
  );
  if (fallback != null) {
    return <Route<dynamic>>[fallback];
  }
  return const <Route<dynamic>>[];
}

/// Horizontal slide (enter from the right) for in-module navigation.
///
/// Used for Settings sub-pages, Monitor detail/choose flows, Quick→Engineer
/// handoff, etc. Keeps industry L/R Cupertino transitions, including the
/// left-edge swipe-to-pop gesture on nested pages. Under balanced load
/// profile, durations snap to zero.
Route<T> buildAppSlideRoute<T>({
  RouteSettings? settings,
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
  BuildContext? context,
  bool? snap,
}) {
  final effectiveSnap = snap ??
      (context != null &&
          (LoadProfileScope.maybeOf(context)?.snapPageTransitions ?? false));
  return _LoadAwareCupertinoPageRoute<T>(
    settings: settings,
    builder: builder,
    fullscreenDialog: fullscreenDialog,
    snap: effectiveSnap,
  );
}

/// Push [page] with [buildAppSlideRoute] (in-module L/R slide).
Future<T?> pushAppSlidePage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    buildAppSlideRoute<T>(context: context, builder: (_) => page),
  );
}

final class _LoadAwareCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _LoadAwareCupertinoPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    required this.snap,
  });

  final bool snap;

  @override
  Duration get transitionDuration =>
      snap ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      snap ? Duration.zero : super.reverseTransitionDuration;
}
