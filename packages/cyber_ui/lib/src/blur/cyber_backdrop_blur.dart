import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cyber_ui/src/blur/cyber_backdrop_blur_controller.dart';
import 'package:cyber_ui/src/blur/cyber_blur_backdrop_scope.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_overlay.dart';
import 'package:cyber_ui/src/blur/cyber_blur_sample_mode.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';

/// Soft frosted fill used when capture is unavailable (no scope / failure).
const Color kCyberFakeGlassFill = Color(0x33FFFFFF);
const Color kCyberFakeGlassBorder = Color(0x44FFFFFF);

/// Applies Gaussian backdrop blur with a selectable sampling policy.
///
/// **Two schemes** (see [CyberBlurSampleMode]):
/// - Realtime Gaussian (default): [CyberBlurSampleMode.realtime] → Material
///   [BackdropFilter] + [ImageFilter.blur].
/// - Static sampling (FrostUI): [firstFrame] / [onChange] / [followLayout]
///   → capture from [CyberBlurBackdropScope]; [followLayout] offsets a shared
///   blurred backdrop so scroll keeps wallpaper perspective aligned.
///
/// [CyberBlurIntensity.transparent] skips blur and overlay (border-only host).
///
/// Overlay tint follows lws-ui: [blurTint] RGB + [intensity] overlay alpha,
/// unless [tint] is set explicitly.
///
/// Downscales capture by [captureScaleFactor] (lws-ui `BLUR_SCALE_FACTOR = 3`)
/// before blur to keep RK356x cost bounded.
class CyberBackdropBlur extends StatefulWidget {
  const CyberBackdropBlur({
    super.key,
    required this.child,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.intensity = CyberBlurIntensity.medium,
    this.blurTint = CyberBlurTint.dark,
    this.sigmaX,
    this.sigmaY,
    this.sampleToken,
    this.controller,
    this.tint,
    this.captureScaleFactor = 3,
    this.clipBehavior = Clip.antiAlias,
    this.backdropScope,
    this.captureTarget = CyberBlurCaptureTarget.surface,
  });

  final Widget child;

  /// Sampling policy; product assigns per surface later.
  final CyberBlurSampleMode sampleMode;

  final CyberBlurIntensity intensity;

  /// Preset RGB for the frost overlay (alpha from [intensity]).
  final CyberBlurTint blurTint;

  /// Override X sigma; defaults to [intensity]'s sigma.
  final double? sigmaX;

  /// Override Y sigma; defaults to [intensity]'s sigma.
  final double? sigmaY;

  /// When [sampleMode] is [CyberBlurSampleMode.onChange], a new token value
  /// triggers a re-sample (e.g. clock minute string, layout generation).
  /// For [CyberBlurSampleMode.followLayout], also invalidates the shared
  /// full-backdrop capture.
  final Object? sampleToken;

  /// Optional manual / shared re-sample driver for on-change / followLayout.
  final CyberBackdropBlurController? controller;

  /// Explicit overlay color; when null, resolved from [intensity] + [blurTint].
  final Color? tint;

  /// Capture downscale divisor (≥1). Matches lws-ui FrostBlurViewSupport.
  final double captureScaleFactor;

  final Clip clipBehavior;

  /// Capture root when this widget sits outside [CyberBlurBackdropScope]
  /// (e.g. root [Overlay] / dialog route). Prefer Flutter [BackdropFilter]
  /// via [CyberBlurSampleMode.realtime] when still in the page tree.
  final CyberBlurBackdropScopeState? backdropScope;

  /// Surface captured from [backdropScope]. IME overlays use [currentPage]
  /// so their frost includes the active page's visible content.
  final CyberBlurCaptureTarget captureTarget;

  @override
  State<CyberBackdropBlur> createState() => _CyberBackdropBlurState();
}

class _CyberBackdropBlurState extends State<CyberBackdropBlur> {
  /// Owned crop for [firstFrame] / [onChange].
  ui.Image? _frozen;

  /// Cloned handle of the scope's pre-blurred backdrop for [followLayout].
  ui.Image? _followBlurred;

  bool _capturePending = false;
  bool _useFakeGlass = false;
  int _listenGeneration = -1;
  int _captureRetryCount = 0;

  ScrollPosition? _scrollPosition;
  Offset _followOrigin = Offset.zero;
  Size _followBackdropSize = Size.zero;
  double _followScale = 1;
  double? _followScrollPixelsAtOrigin;

  double get _sigmaX => widget.sigmaX ?? widget.intensity.sigma;
  double get _sigmaY => widget.sigmaY ?? widget.intensity.sigma;

  bool get _isFollowLayout =>
      widget.sampleMode == CyberBlurSampleMode.followLayout;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onController);
    if (widget.intensity.usesBackdropBlur &&
        widget.sampleMode != CyberBlurSampleMode.realtime) {
      _scheduleCapture(settlePasses: 2);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindScrollPosition();
  }

  @override
  void didUpdateWidget(CyberBackdropBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onController);
      widget.controller?.addListener(_onController);
    }

    if (widget.sampleMode == CyberBlurSampleMode.realtime) {
      _unbindScrollPosition();
      _clearFrozen();
      return;
    }

    if (oldWidget.sampleMode != widget.sampleMode ||
        oldWidget.sigmaX != widget.sigmaX ||
        oldWidget.sigmaY != widget.sigmaY ||
        oldWidget.intensity != widget.intensity ||
        oldWidget.backdropScope != widget.backdropScope) {
      _captureRetryCount = 0;
      _scheduleCapture(settlePasses: 2);
      return;
    }

    if ((widget.sampleMode == CyberBlurSampleMode.onChange ||
            widget.sampleMode == CyberBlurSampleMode.followLayout) &&
        oldWidget.sampleToken != widget.sampleToken) {
      if (_isFollowLayout) {
        _invalidateSharedCapture();
      }
      _captureRetryCount = 0;
      _scheduleCapture(settlePasses: 1);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _unbindScrollPosition();
    _frozen?.dispose();
    _followBlurred?.dispose();
    super.dispose();
  }

  CyberBlurBackdropScopeState? get _scope =>
      widget.backdropScope ?? CyberBlurBackdropScope.maybeOf(context);

  void _invalidateSharedCapture() {
    _scope?.invalidateFullCapture();
  }

  void _bindScrollPosition() {
    if (!_isFollowLayout) {
      _unbindScrollPosition();
      return;
    }
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _scrollPosition)) {
      return;
    }
    _scrollPosition = next;
    _updateFollowGeometry();
  }

  void _unbindScrollPosition() => _scrollPosition = null;

  void _updateFollowGeometry() {
    final scope = _scope;
    final boundary = scope?.renderBoundaryFor(widget.captureTarget);
    if (boundary == null || !boundary.hasSize || _followBlurred == null) {
      return;
    }

    final self = context.findRenderObject();
    if (self is! RenderBox ||
        !self.hasSize ||
        !self.size.width.isFinite ||
        !self.size.height.isFinite) {
      return;
    }

    final origin = boundary.globalToLocal(self.localToGlobal(Offset.zero));
    final backdropSize = Size(
      _followBlurred!.width / _followScale,
      _followBlurred!.height / _followScale,
    );

    if ((origin.dx - _followOrigin.dx).abs() < 0.25 &&
        (origin.dy - _followOrigin.dy).abs() < 0.25 &&
        (backdropSize.width - _followBackdropSize.width).abs() < 0.25 &&
        (backdropSize.height - _followBackdropSize.height).abs() < 0.25) {
      return;
    }

    setState(() {
      _followOrigin = origin;
      _followBackdropSize = backdropSize;
      _followScrollPixelsAtOrigin = _scrollPosition?.pixels;
    });
  }

  void _onController() {
    final gen = widget.controller?.generation ?? -1;
    if (gen == _listenGeneration) {
      return;
    }
    _listenGeneration = gen;
    if (widget.sampleMode == CyberBlurSampleMode.onChange ||
        widget.sampleMode == CyberBlurSampleMode.firstFrame ||
        widget.sampleMode == CyberBlurSampleMode.followLayout) {
      if (_isFollowLayout) {
        _invalidateSharedCapture();
      }
      _scheduleCapture(settlePasses: 1);
    }
  }

  void _clearFrozen() {
    _frozen?.dispose();
    _frozen = null;
    _followBlurred?.dispose();
    _followBlurred = null;
    _useFakeGlass = false;
    _followOrigin = Offset.zero;
    _followBackdropSize = Size.zero;
    _followScrollPixelsAtOrigin = null;
  }

  Offset _followScrollTranslation() {
    final position = _scrollPosition;
    final initialPixels = _followScrollPixelsAtOrigin;
    if (position == null || initialPixels == null) {
      return Offset.zero;
    }
    final delta = position.pixels - initialPixels;
    return switch (position.axisDirection) {
      AxisDirection.down => Offset(0, delta),
      AxisDirection.up => Offset(0, -delta),
      AxisDirection.right => Offset(delta, 0),
      AxisDirection.left => Offset(-delta, 0),
    };
  }

  Widget _followLayoutImage() {
    final image = RawImage(
      image: _followBlurred,
      width: _followBackdropSize.width,
      height: _followBackdropSize.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
    final position = _scrollPosition;
    if (position == null || _followScrollPixelsAtOrigin == null) {
      return image;
    }
    // ScrollPosition notifies before the next paint. Counter-translate the
    // shared backdrop in that same frame, rather than waiting for a
    // post-frame global-coordinate measurement that visibly jumps on a
    // FittedBox-scaled simulator.
    return AnimatedBuilder(
      animation: position,
      child: image,
      builder: (context, child) => Transform.translate(
        offset: _followScrollTranslation(),
        child: child!,
      ),
    );
  }

  void _scheduleCapture({required int settlePasses}) {
    if (!mounted || widget.sampleMode == CyberBlurSampleMode.realtime) {
      return;
    }
    void pass(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (remaining > 1) {
          pass(remaining - 1);
          return;
        }
        unawaited(_captureBackdrop());
      });
    }

    pass(settlePasses.clamp(1, 4));
  }

  Future<void> _captureBackdrop() async {
    if (!mounted || _capturePending) {
      return;
    }
    if (widget.sampleMode == CyberBlurSampleMode.firstFrame &&
        _frozen != null) {
      return;
    }

    if (_isFollowLayout) {
      await _captureFollowLayout();
      return;
    }

    final scope = _scope;
    final boundary = scope?.renderBoundaryFor(widget.captureTarget);
    if (boundary == null || !boundary.hasSize) {
      _enableFakeGlass(
        scope == null ? 'scope-missing' : 'capture-target-unavailable',
      );
      return;
    }

    final self = context.findRenderObject();
    if (self is! RenderBox ||
        !self.hasSize ||
        !self.size.width.isFinite ||
        !self.size.height.isFinite ||
        self.size.width < 1 ||
        self.size.height < 1) {
      if (_captureRetryCount < 12) {
        _captureRetryCount++;
        _scheduleCapture(settlePasses: 1);
      }
      return;
    }

    _capturePending = true;
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale = (dpr / widget.captureScaleFactor).clamp(0.25, dpr);
      final full = await boundary.toImage(pixelRatio: scale);
      if (!mounted) {
        full.dispose();
        return;
      }

      final boundaryBox = boundary;
      // Must use globalToLocal — subtracting global offsets breaks when an
      // ancestor FittedBox/Transform scales the tree (sim density match in
      // app.dart): globals are in the outer space, toImage is in local layout
      // space. Re-resolve [self] after the async gap.
      final selfBox = context.findRenderObject();
      if (selfBox is! RenderBox || !selfBox.hasSize) {
        full.dispose();
        _capturePending = false;
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _scheduleCapture(settlePasses: 1);
        }
        return;
      }
      final localOrigin =
          boundaryBox.globalToLocal(selfBox.localToGlobal(Offset.zero));
      final src = Rect.fromLTWH(
        localOrigin.dx * scale,
        localOrigin.dy * scale,
        selfBox.size.width * scale,
        selfBox.size.height * scale,
      ).intersect(
        Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      );

      if (src.width < 1 || src.height < 1) {
        full.dispose();
        // Layout can settle after the first post-frame callbacks; the card
        // may briefly sit outside the capture target.
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _capturePending = false;
          _scheduleCapture(settlePasses: 1);
          return;
        }
        if (mounted) {
          _enableFakeGlass('crop-out-of-bounds', details: 'src=$src');
        }
        return;
      }

      final cropped = await _cropImage(full, src);
      final cropMean = await _meanRgb(cropped);
      full.dispose();
      if (!mounted) {
        cropped.dispose();
        return;
      }

      // Wallpaper Image often paints after the first settle passes on the
      // embedder — a successful crop of an all-black buffer reads as an
      // opaque plate. Retry a few frames before accepting black.
      if (cropMean < 2.0) {
        cropped.dispose();
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _capturePending = false;
          _scheduleCapture(settlePasses: 1);
          return;
        }
        _enableFakeGlass('capture-all-black', details: 'mean=$cropMean');
        return;
      }

      setState(() {
        _frozen?.dispose();
        _frozen = cropped;
        _followBlurred = null;
        _useFakeGlass = false;
      });
    } catch (error, stackTrace) {
      _enableFakeGlass('capture-exception', details: '$error\n$stackTrace');
    } finally {
      _capturePending = false;
    }
  }

  Future<void> _captureFollowLayout() async {
    if (!mounted || _capturePending) {
      return;
    }
    _capturePending = true;
    try {
      final scope = _scope;
      if (scope == null) {
        _enableFakeGlass('scope-missing');
        return;
      }

      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale = (dpr / widget.captureScaleFactor).clamp(0.25, dpr);
      _followScale = scale;

      final full = await scope.acquireFullCapture(
        pixelRatio: scale,
        target: widget.captureTarget,
      );
      if (!mounted) {
        return;
      }
      if (full == null) {
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _capturePending = false;
          _scheduleCapture(settlePasses: 1);
          return;
        }
        _enableFakeGlass('capture-target-unavailable');
        return;
      }

      final mean = await _meanRgb(full);
      if (!mounted) {
        return;
      }
      if (mean < 2.0) {
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          scope.invalidateFullCapture();
          _capturePending = false;
          _scheduleCapture(settlePasses: 1);
          return;
        }
        _enableFakeGlass('capture-all-black', details: 'mean=$mean');
        return;
      }

      // Blur runs in capture-pixel space; downscale (dpr / scaleFactor) would
      // otherwise make the same logical sigma look ~scaleFactor× heavier when
      // the snapshot is stretched back to layout size (common on SIM dpr=1).
      final blurred = await scope.acquireBlurredCapture(
        pixelRatio: scale,
        sigmaX: _sigmaX * scale,
        sigmaY: _sigmaY * scale,
        target: widget.captureTarget,
      );
      if (!mounted || blurred == null) {
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _capturePending = false;
          _scheduleCapture(settlePasses: 1);
        } else {
          _enableFakeGlass('blurred-capture-unavailable');
        }
        return;
      }

      final cloned = blurred.clone();
      setState(() {
        _frozen?.dispose();
        _frozen = null;
        _followBlurred?.dispose();
        _followBlurred = cloned;
        _useFakeGlass = false;
        _followBackdropSize = Size(
          cloned.width / scale,
          cloned.height / scale,
        );
      });
      _bindScrollPosition();
      _updateFollowGeometry();
    } catch (error, stackTrace) {
      _enableFakeGlass(
        'follow-layout-exception',
        details: '$error\n$stackTrace',
      );
    } finally {
      _capturePending = false;
    }
  }

  void _enableFakeGlass(String reason, {String? details}) {
    if (!mounted) return;
    debugPrint(
      'cyber-backdrop: fake-glass reason=$reason '
      'mode=${widget.sampleMode.name} target=${widget.captureTarget.name} '
      'retry=$_captureRetryCount${details == null ? '' : ' $details'}',
    );
    setState(() => _useFakeGlass = true);
  }

  static bool get _inWidgetTest {
    // Avoid importing flutter_test; its bindings never complete [toByteData].
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  static Future<double> _meanRgb(ui.Image image) async {
    // Widget tests: skip the probe (toByteData hangs on the test binding).
    // Device/emulator: reject all-black wallpaper settle frames.
    if (_inWidgetTest) {
      return 255;
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null || byteData.lengthInBytes < 4) {
      return 0;
    }
    final bytes = byteData.buffer.asUint8List();
    final step = ((bytes.length ~/ 4 ~/ 64).clamp(1, 4096) * 4).toInt();
    var mean = 0.0;
    var samples = 0;
    for (var i = 0; i + 2 < bytes.length; i += step) {
      mean += (bytes[i] + bytes[i + 1] + bytes[i + 2]) / 3.0;
      samples++;
    }
    return samples == 0 ? 0 : mean / samples;
  }

  static Future<ui.Image> _cropImage(ui.Image src, Rect srcRect) async {
    final w = srcRect.width.round().clamp(1, src.width);
    final h = srcRect.height.round().clamp(1, src.height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dst = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    canvas.drawImageRect(src, srcRect, dst, Paint());
    final picture = recorder.endRecording();
    try {
      return picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blurOn = widget.intensity.usesBackdropBlur;

    final content = Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: [
        if (blurOn && widget.sampleMode == CyberBlurSampleMode.realtime)
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: _sigmaX,
                sigmaY: _sigmaY,
                tileMode: TileMode.clamp,
              ),
              child: const SizedBox.expand(),
            ),
          )
        else if (blurOn && _isFollowLayout && _followBlurred != null)
          Positioned(
            left: -_followOrigin.dx,
            top: -_followOrigin.dy,
            width: _followBackdropSize.width,
            height: _followBackdropSize.height,
            child: _followLayoutImage(),
          )
        else if (blurOn && _frozen != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: _sigmaX,
                sigmaY: _sigmaY,
                tileMode: TileMode.clamp,
              ),
              child: RawImage(
                image: _frozen,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          )
        else if (blurOn && _useFakeGlass)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kCyberFakeGlassFill,
                border: Border.fromBorderSide(
                  BorderSide(color: kCyberFakeGlassBorder),
                ),
              ),
            ),
          ),
        if (widget.tint != null)
          Positioned.fill(
            child: ColoredBox(color: widget.tint!),
          )
        else if (widget.intensity.drawsOverlay)
          Positioned.fill(
            child: ColoredBox(
              color: cyberBlurOverlayColor(
                intensity: widget.intensity,
                tint: widget.blurTint,
              ),
            ),
          ),
        widget.child,
      ],
    );

    return ClipRect(
      clipBehavior: widget.clipBehavior,
      child: content,
    );
  }
}
