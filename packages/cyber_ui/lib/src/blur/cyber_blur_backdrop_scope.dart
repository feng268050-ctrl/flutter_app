import 'dart:ui' as ui;

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

  ui.Image? _sharedFull;
  double? _sharedPixelRatio;
  Future<ui.Image?>? _inflightCapture;

  ui.Image? _sharedBlurred;
  double? _blurredSigmaX;
  double? _blurredSigmaY;
  double? _blurredPixelRatio;
  Future<ui.Image?>? _inflightBlur;

  RenderRepaintBoundary? get renderBoundary {
    final object = boundaryKey.currentContext?.findRenderObject();
    return object is RenderRepaintBoundary ? object : null;
  }

  /// Shared downscaled backdrop snapshot. Ownership stays with this scope —
  /// do not dispose the returned image.
  Future<ui.Image?> acquireFullCapture({required double pixelRatio}) async {
    if (_sharedFull != null &&
        _sharedPixelRatio == pixelRatio &&
        _sharedFull!.width > 0 &&
        _sharedFull!.height > 0) {
      return _sharedFull;
    }

    if (_inflightCapture != null) {
      await _inflightCapture;
      if (_sharedFull != null && _sharedPixelRatio == pixelRatio) {
        return _sharedFull;
      }
    }

    final boundary = renderBoundary;
    if (boundary == null || !boundary.hasSize) {
      return null;
    }

    final future = boundary.toImage(pixelRatio: pixelRatio);
    _inflightCapture = future;
    try {
      final image = await future;
      if (!mounted) {
        image.dispose();
        return null;
      }
      _sharedFull?.dispose();
      _sharedBlurred?.dispose();
      _sharedBlurred = null;
      _blurredSigmaX = null;
      _blurredSigmaY = null;
      _blurredPixelRatio = null;
      _sharedFull = image;
      _sharedPixelRatio = pixelRatio;
      return image;
    } finally {
      _inflightCapture = null;
    }
  }

  /// Pre-blurred full backdrop for [CyberBlurSampleMode.followLayout] panels
  /// that offset-sample as they scroll. Ownership stays with this scope.
  Future<ui.Image?> acquireBlurredCapture({
    required double pixelRatio,
    required double sigmaX,
    required double sigmaY,
  }) async {
    if (_sharedBlurred != null &&
        _blurredPixelRatio == pixelRatio &&
        _blurredSigmaX == sigmaX &&
        _blurredSigmaY == sigmaY) {
      return _sharedBlurred;
    }

    if (_inflightBlur != null) {
      await _inflightBlur;
      if (_sharedBlurred != null &&
          _blurredPixelRatio == pixelRatio &&
          _blurredSigmaX == sigmaX &&
          _blurredSigmaY == sigmaY) {
        return _sharedBlurred;
      }
    }

    final full = await acquireFullCapture(pixelRatio: pixelRatio);
    if (full == null) {
      return null;
    }

    final future = _blurImage(full, sigmaX: sigmaX, sigmaY: sigmaY);
    _inflightBlur = future;
    try {
      final blurred = await future;
      if (!mounted) {
        blurred.dispose();
        return null;
      }
      _sharedBlurred?.dispose();
      _sharedBlurred = blurred;
      _blurredSigmaX = sigmaX;
      _blurredSigmaY = sigmaY;
      _blurredPixelRatio = pixelRatio;
      return blurred;
    } finally {
      _inflightBlur = null;
    }
  }

  /// Drop shared snapshots (wallpaper swap / manual re-sample).
  void invalidateFullCapture() {
    _sharedFull?.dispose();
    _sharedFull = null;
    _sharedPixelRatio = null;
    _sharedBlurred?.dispose();
    _sharedBlurred = null;
    _blurredSigmaX = null;
    _blurredSigmaY = null;
    _blurredPixelRatio = null;
  }

  static Future<ui.Image> _blurImage(
    ui.Image src, {
    required double sigmaX,
    required double sigmaY,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigmaX,
        sigmaY: sigmaY,
        tileMode: TileMode.clamp,
      );
    canvas.drawImage(src, Offset.zero, paint);
    final picture = recorder.endRecording();
    try {
      return picture.toImage(src.width, src.height);
    } finally {
      picture.dispose();
    }
  }

  @override
  void dispose() {
    invalidateFullCapture();
    super.dispose();
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
