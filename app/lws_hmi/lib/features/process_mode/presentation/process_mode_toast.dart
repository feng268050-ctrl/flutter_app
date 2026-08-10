import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Short toast for process-mode device feedback (lws-ui ToastUtils look).
///
/// Target chrome: **light** frosted pill + **dark** text, with full-page
/// matrix 透视 + display-time Gaussian (σ=[blurSigma]) — same bleed idea as
/// warn/tip LIGHT glass. Display-time [ImageFiltered] (not bake-only) matches
/// the crop path that actually softens on Weston/SWGL.
///
/// Hosted by [ProcessModeToastLayer] so capture samples page chrome (Weston
/// Overlay [BackdropFilter] composites as a black/opaque plate).
abstract final class ProcessModeToast {
  static const Duration shortDuration = Duration(milliseconds: 2000);

  /// Supporting (16) + 3 — product toast readability.
  static const double textSize = 19;
  static const double bottomInset = 20;
  static const double cornerRadius = 18;
  static const double blurSigma = 30;
  static const double verticalPadding = 12;
  static const double horizontalPadding = 19;

  /// Android lws-ui `toast_frame.xml`: `#e6eeeeee`.
  ///
  /// Keep the same translucent neutral plate over our σ=30 matrix capture so
  /// the background perspective remains subtle rather than becoming white.
  static const Color frostFill = Color(0xE6EEEEEE);

  /// Same frame while the first snapshot is pending; avoids a colour flash.
  static const Color frostFillInterim = frostFill;

  /// Android lws-ui `primary_text_default_material_light`: `#de000000`.
  static const Color textColor = Color(0xDE000000);

  static OverlayEntry? _fallbackEntry;
  static Timer? _fallbackTimer;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = shortDuration,
  }) {
    if (message.isEmpty) {
      return;
    }
    final layer =
        ProcessModeToastLayer.maybeOf(context) ?? ProcessModeToastLayer._active;
    if (layer != null) {
      layer.show(message, duration: duration);
      return;
    }
    debugPrint('process-mode-toast: no layer — fallback overlay (no blur)');
    _showFallbackOverlay(context, message, duration);
  }

  static void _showFallbackOverlay(
    BuildContext context,
    String message,
    Duration duration,
  ) {
    dismiss();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: bottomInset,
                left: 32,
                right: 32,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ProcessModeToastPill(
                    message: message,
                    capture: null,
                    pageLogicalSize: null,
                    pillOriginInPage: Offset.zero,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _fallbackEntry = entry;
    overlay.insert(entry);
    _fallbackTimer = Timer(duration, () {
      if (identical(_fallbackEntry, entry)) {
        dismiss();
      }
    });
  }

  static void dismiss() {
    ProcessModeToastLayer.dismissActive();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackEntry?.remove();
    _fallbackEntry = null;
  }

  @visibleForTesting
  static void resetForTest() => dismiss();
}

/// In-page toast host with [RepaintBoundary] capture for Gaussian frost.
final class ProcessModeToastLayer extends StatefulWidget {
  const ProcessModeToastLayer({super.key, required this.child});

  final Widget child;

  static ProcessModeToastLayerState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ProcessModeToastLayerState>();
  }

  static ProcessModeToastLayerState? _active;

  static void dismissActive() => _active?.clear();

  @override
  State<ProcessModeToastLayer> createState() => ProcessModeToastLayerState();
}

final class ProcessModeToastLayerState extends State<ProcessModeToastLayer> {
  final GlobalKey _boundaryKey =
      GlobalKey(debugLabel: 'processModeToastCapture');
  final GlobalKey _pillKey = GlobalKey(debugLabel: 'processModeToastPill');

  String? _message;
  ui.Image? _capture;
  Size? _pageLogicalSize;
  Offset _pillOriginInPage = Offset.zero;
  Timer? _timer;
  var _captureGen = 0;

  void show(String message, {Duration duration = ProcessModeToast.shortDuration}) {
    _timer?.cancel();
    _capture?.dispose();
    _capture = null;
    _pageLogicalSize = null;
    _pillOriginInPage = Offset.zero;
    final gen = ++_captureGen;
    setState(() => _message = message);
    // Dismiss on wall clock from first paint — do not wait for slow toImage.
    _timer = Timer(duration, clear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sampleCapture(gen));
    });
  }

  Future<void> _sampleCapture(int gen) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!mounted || _message == null || gen != _captureGen) {
        return;
      }
      final sample = await _captureFullPage();
      if (!mounted || _message == null || gen != _captureGen) {
        sample?.image.dispose();
        return;
      }
      if (sample != null) {
        setState(() {
          _capture?.dispose();
          _capture = sample.image;
          _pageLogicalSize = sample.pageLogicalSize;
          _pillOriginInPage = sample.pillOriginInPage;
        });
        return;
      }
      debugPrint('process-mode-toast: capture miss attempt=$attempt — retry');
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
    }
    debugPrint('process-mode-toast: capture gave up — cream-only frost');
  }

  Future<({ui.Image image, Size pageLogicalSize, Offset pillOriginInPage})?>
      _captureFullPage() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final pillContext = _pillKey.currentContext;
    final self = pillContext?.findRenderObject();
    if (boundary == null || !boundary.hasSize) {
      debugPrint('process-mode-toast: skip — no boundary');
      return null;
    }
    if (self is! RenderBox || !self.hasSize || self.size.isEmpty) {
      debugPrint('process-mode-toast: skip — pill not laid out');
      return null;
    }
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      // Match warn / tip BLUR_SCALE_FACTOR ≈ 3.
      final scale = (dpr / 3).clamp(0.25, dpr);
      final full = await boundary.toImage(pixelRatio: scale);
      final origin =
          self.localToGlobal(Offset.zero) - boundary.localToGlobal(Offset.zero);
      final pageLogical = boundary.size;
      debugPrint(
        'process-mode-toast: capture ok page='
        '${pageLogical.width.toStringAsFixed(0)}x'
        '${pageLogical.height.toStringAsFixed(0)} '
        'pill=${self.size.width.toStringAsFixed(0)}x'
        '${self.size.height.toStringAsFixed(0)} '
        'origin=${origin.dx.toStringAsFixed(0)},${origin.dy.toStringAsFixed(0)} '
        'scale=${scale.toStringAsFixed(2)} sigma=${ProcessModeToast.blurSigma}',
      );
      return (
        image: full,
        pageLogicalSize: pageLogical,
        pillOriginInPage: origin,
      );
    } catch (e) {
      debugPrint('process-mode-toast: capture failed: $e');
      return null;
    }
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _captureGen++;
    _capture?.dispose();
    _capture = null;
    _pageLogicalSize = null;
    _pillOriginInPage = Offset.zero;
    if (_message == null) {
      return;
    }
    if (mounted) {
      setState(() => _message = null);
    } else {
      _message = null;
    }
  }

  @override
  void initState() {
    super.initState();
    ProcessModeToastLayer._active = this;
  }

  @override
  void dispose() {
    if (identical(ProcessModeToastLayer._active, this)) {
      ProcessModeToastLayer._active = null;
    }
    _timer?.cancel();
    _capture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: widget.child,
        ),
        if (_message != null)
          Positioned(
            left: 32,
            right: 32,
            bottom: ProcessModeToast.bottomInset,
            child: IgnorePointer(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ProcessModeToastPill(
                    key: _pillKey,
                    message: _message!,
                    capture: _capture,
                    pageLogicalSize: _pageLogicalSize,
                    pillOriginInPage: _pillOriginInPage,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Light frosted pill — full-page matrix 透视 + display Gaussian + cream tint.
final class ProcessModeToastPill extends StatelessWidget {
  const ProcessModeToastPill({
    super.key,
    required this.message,
    required this.capture,
    required this.pageLogicalSize,
    required this.pillOriginInPage,
  });

  final String message;
  final ui.Image? capture;
  final Size? pageLogicalSize;
  final Offset pillOriginInPage;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ProcessModeToast.cornerRadius);
    final hasPlate = capture != null && pageLogicalSize != null;
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _backdropLayer(hasPlate: hasPlate)),
          Positioned.fill(
            child: ColoredBox(
              color: hasPlate
                  ? ProcessModeToast.frostFill
                  : ProcessModeToast.frostFillInterim,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProcessModeToast.horizontalPadding,
              vertical: ProcessModeToast.verticalPadding,
            ),
            child: Text(
              message,
              key: const ValueKey('process-mode-toast'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ProcessModeToast.textColor,
                fontSize: ProcessModeToast.textSize,
                height: 1.2,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backdropLayer({required bool hasPlate}) {
    if (!hasPlate) {
      return const ColoredBox(color: ProcessModeToast.frostFillInterim);
    }
    final page = pageLogicalSize!;
    final blurred = capture!;
    // Full-page plate + matrix translate (warn/tip 透视), softens via display
    // ImageFiltered — σ in logical px, same recipe as the working crop toast.
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: ProcessModeToast.blurSigma,
          sigmaY: ProcessModeToast.blurSigma,
          tileMode: TileMode.clamp,
        ),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -pillOriginInPage.dx,
              top: -pillOriginInPage.dy,
              width: page.width,
              height: page.height,
              child: RawImage(
                image: blurred,
                width: page.width,
                height: page.height,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
