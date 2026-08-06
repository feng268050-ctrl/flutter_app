import 'package:flutter/widgets.dart';

/// Pauses Home decorative WebP under **opaque** routes (Settings / Monitor / …)
/// while keeping it live under **non-opaque** overlays (dialogs / tips) so frost
/// blur still shows motion.
///
/// Register on the root [Navigator] next to [appRouteObserver].
final HomeWebpCoverageGate homeWebpCoverageGate = HomeWebpCoverageGate();

/// Navigator stack gate for [PacedHomeWebpController] pause/resume.
final class HomeWebpCoverageGate extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];
  Route<dynamic>? _homeRoute;
  bool _pauseWebp = false;

  /// True when an opaque route sits above the attached Home route.
  bool get pauseWebp => _pauseWebp;

  /// Home [PageRoute] to treat as the decoration owner.
  void attachHome(Route<dynamic> route) {
    if (identical(_homeRoute, route)) {
      return;
    }
    _homeRoute = route;
    _recompute();
  }

  void detachHome(Route<dynamic> route) {
    if (!identical(_homeRoute, route)) {
      return;
    }
    _homeRoute = null;
    _recompute();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _recompute();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _recompute();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _recompute();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0) {
      if (newRoute != null) {
        _stack[i] = newRoute;
      } else {
        _stack.removeAt(i);
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _recompute();
  }

  void _recompute() {
    final home = _homeRoute;
    var pause = false;
    if (home != null) {
      final homeIndex = _stack.indexOf(home);
      if (homeIndex >= 0) {
        for (var i = homeIndex + 1; i < _stack.length; i++) {
          final above = _stack[i];
          // [Route] itself has no opacity; full-screen pages are opaque
          // [ModalRoute]s. Dialogs / tips are non-opaque ModalRoutes.
          if (above is ModalRoute && above.opaque) {
            pause = true;
            break;
          }
        }
      }
    }
    if (pause == _pauseWebp) {
      return;
    }
    _pauseWebp = pause;
    notifyListeners();
  }

  /// Test helper: clear tracked stack / home without a real navigator.
  @visibleForTesting
  void debugReset() {
    _stack.clear();
    _homeRoute = null;
    _pauseWebp = false;
  }

  /// Test helper: mirror [didPush] without a navigator.
  @visibleForTesting
  void debugPush(Route<dynamic> route) => didPush(route, null);

  /// Test helper: mirror [didPop] without a navigator.
  @visibleForTesting
  void debugPop(Route<dynamic> route) => didPop(route, null);
}
