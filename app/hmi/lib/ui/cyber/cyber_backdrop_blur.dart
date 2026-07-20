import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lws_hmi/ui/cyber/cyber_backdrop_blur_controller.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_backdrop_scope.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_intensity.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_overlay.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_sample_mode.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_tint.dart';

/// Soft frosted fill used when capture is unavailable (no scope / failure).
const Color kCyberFakeGlassFill = Color(0x33FFFFFF);
const Color kCyberFakeGlassBorder = Color(0x44FFFFFF);

/// Applies Gaussian backdrop blur with a selectable sampling policy.
///
/// - [CyberBlurSampleMode.realtime] (default): [BackdropFilter] every frame.
/// - [CyberBlurSampleMode.firstFrame]: capture once from
///   [CyberBlurBackdropScope], then freeze.
/// - [CyberBlurSampleMode.onChange]: re-capture when [sampleToken] or
///   [controller] generation changes.
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
  final Object? sampleToken;

  /// Optional manual / shared re-sample driver for on-change mode.
  final CyberBackdropBlurController? controller;

  /// Explicit overlay color; when null, resolved from [intensity] + [blurTint].
  final Color? tint;

  /// Capture downscale divisor (≥1). Matches lws-ui FrostBlurViewSupport.
  final double captureScaleFactor;

  final Clip clipBehavior;

  @override
  State<CyberBackdropBlur> createState() => _CyberBackdropBlurState();
}

class _CyberBackdropBlurState extends State<CyberBackdropBlur> {
  ui.Image? _frozen;
  bool _capturePending = false;
  bool _useFakeGlass = false;
  int _listenGeneration = -1;

  double get _sigmaX => widget.sigmaX ?? widget.intensity.sigma;
  double get _sigmaY => widget.sigmaY ?? widget.intensity.sigma;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onController);
    if (widget.sampleMode != CyberBlurSampleMode.realtime) {
      _scheduleCapture(settlePasses: 2);
    }
  }

  @override
  void didUpdateWidget(CyberBackdropBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onController);
      widget.controller?.addListener(_onController);
    }

    if (widget.sampleMode == CyberBlurSampleMode.realtime) {
      _clearFrozen();
      return;
    }

    if (oldWidget.sampleMode != widget.sampleMode) {
      _scheduleCapture(settlePasses: 2);
      return;
    }

    if (widget.sampleMode == CyberBlurSampleMode.onChange &&
        oldWidget.sampleToken != widget.sampleToken) {
      _scheduleCapture(settlePasses: 1);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _frozen?.dispose();
    super.dispose();
  }

  void _onController() {
    final gen = widget.controller?.generation ?? -1;
    if (gen == _listenGeneration) {
      return;
    }
    _listenGeneration = gen;
    if (widget.sampleMode == CyberBlurSampleMode.onChange ||
        widget.sampleMode == CyberBlurSampleMode.firstFrame) {
      _scheduleCapture(settlePasses: 1);
    }
  }

  void _clearFrozen() {
    _frozen?.dispose();
    _frozen = null;
    _useFakeGlass = false;
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
        _captureBackdrop();
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

    final scope = CyberBlurBackdropScope.maybeOf(context);
    final boundary = scope?.renderBoundary;
    if (boundary == null || !boundary.hasSize) {
      if (mounted) {
        setState(() => _useFakeGlass = true);
      }
      return;
    }

    final self = context.findRenderObject();
    if (self is! RenderBox || !self.hasSize) {
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
      final selfTopLeft = self.localToGlobal(Offset.zero);
      final boundaryTopLeft = boundaryBox.localToGlobal(Offset.zero);
      final localOrigin = selfTopLeft - boundaryTopLeft;
      final src = Rect.fromLTWH(
        localOrigin.dx * scale,
        localOrigin.dy * scale,
        self.size.width * scale,
        self.size.height * scale,
      ).intersect(Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()));

      if (src.width < 1 || src.height < 1) {
        full.dispose();
        if (mounted) {
          setState(() => _useFakeGlass = true);
        }
        return;
      }

      final cropped = await _cropImage(full, src);
      full.dispose();
      if (!mounted) {
        cropped.dispose();
        return;
      }

      setState(() {
        _frozen?.dispose();
        _frozen = cropped;
        _useFakeGlass = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _useFakeGlass = true);
      }
    } finally {
      _capturePending = false;
    }
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
    final filter = ui.ImageFilter.blur(
      sigmaX: _sigmaX,
      sigmaY: _sigmaY,
      tileMode: TileMode.clamp,
    );

    final content = Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.sampleMode == CyberBlurSampleMode.realtime)
          Positioned.fill(
            child: BackdropFilter(
              filter: filter,
              child: const SizedBox.expand(),
            ),
          )
        else if (_frozen != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: filter,
              child: RawImage(
                image: _frozen,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          )
        else if (_useFakeGlass)
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
        else
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
