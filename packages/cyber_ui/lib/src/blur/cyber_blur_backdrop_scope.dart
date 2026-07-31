import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Page-level host: descendants (including sibling glass/clock) can resolve the
/// capture [boundaryKey] via [CyberBlurBackdropScope.maybeOf].
///
/// Wrap the whole page stack. Put only backdrop content inside
/// [CyberBlurBackdropTarget] so consumers are not included in the snapshot.
class CyberBlurBackdropScope extends StatefulWidget {
  const CyberBlurBackdropScope({
    super.key,
    required this.child,
  });

  final Widget child;

  /// Nearest scope, or null if absent.
  static CyberBlurBackdropScopeState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CyberBlurBackdropScopeInherited>()
        ?.state;
  }

  /// Resolve a capture root for overlays / dialogs that sit outside the scope.
  ///
  /// Prefers an ancestor, then walks the root [Navigator] subtree (page under
  /// dialog routes). Does not register an InheritedWidget dependency.
  static CyberBlurBackdropScopeState? resolve(BuildContext context) {
    final ancestor =
        context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
    if (ancestor != null) {
      return ancestor;
    }

    final nav = Navigator.maybeOf(context, rootNavigator: true);
    final searchContext = nav?.context ?? context;
    CyberBlurBackdropScopeState? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (element is StatefulElement &&
          element.state is CyberBlurBackdropScopeState) {
        found = element.state as CyberBlurBackdropScopeState;
        return;
      }
      element.visitChildren(visit);
    }

    searchContext.visitChildElements(visit);
    return found;
  }

  @override
  State<CyberBlurBackdropScope> createState() => CyberBlurBackdropScopeState();
}

class CyberBlurBackdropScopeState extends State<CyberBlurBackdropScope> {
  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'cyberBlurBackdrop');

  RenderRepaintBoundary? get renderBoundary {
    final object = boundaryKey.currentContext?.findRenderObject();
    return object is RenderRepaintBoundary ? object : null;
  }

  @override
  Widget build(BuildContext context) {
    return _CyberBlurBackdropScopeInherited(
      state: this,
      child: widget.child,
    );
  }
}

/// Capture root — wallpaper / GIFs only (lws-ui `FrostCaptureTarget` content).
class CyberBlurBackdropTarget extends StatelessWidget {
  const CyberBlurBackdropTarget({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = CyberBlurBackdropScope.maybeOf(context);
    assert(
      scope != null,
      'CyberBlurBackdropTarget requires an ancestor CyberBlurBackdropScope',
    );
    return RepaintBoundary(
      key: scope!.boundaryKey,
      child: child,
    );
  }
}

class _CyberBlurBackdropScopeInherited extends InheritedWidget {
  const _CyberBlurBackdropScopeInherited({
    required this.state,
    required super.child,
  });

  final CyberBlurBackdropScopeState state;

  @override
  bool updateShouldNotify(_CyberBlurBackdropScopeInherited oldWidget) =>
      state != oldWidget.state;
}
