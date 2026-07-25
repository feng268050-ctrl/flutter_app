import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Short toast for process-mode device feedback (lws-ui ToastUtils look).
///
/// Target chrome (device reference): **light** frosted pill + **dark** text over
/// the orange laser trapezoid, with Gaussian blur of the page behind the pill.
///
/// Hosted by [ProcessModeToastLayer] so capture samples page chrome (Weston
/// Overlay [BackdropFilter] composites as a black/opaque plate).
abstract final class ProcessModeToast {
  static const Duration shortDuration = Duration(milliseconds: 2000);

  static const double textSize = 16;
  static const double bottomInset = 20;
  static const double cornerRadius = 18;
  static const double blurSigma = 24;
  static const double verticalPadding = 12;
  static const double horizontalPadding = 22;

  /// Cream frost fill (图一) — keep alpha low enough for blur to read.
  static const Color frostFill = Color(0xB3FFFCFA);

  /// Dark label on light frost.
  static const Color textColor = Color(0xFF1A1A1A);

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
    late final OverlayEntry entry;
    entry = OverlayEntry(
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
  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'processModeToastCapture');
  String? _message;
  ui.Image? _capture;
  Timer? _timer;

  void show(String message, {Duration duration = ProcessModeToast.shortDuration}) {
    _timer?.cancel();
    _capture?.dispose();
    _capture = null;
    setState(() => _message = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sampleThenShow(duration));
    });
  }

  Future<void> _sampleThenShow(Duration duration) async {
    if (!mounted || _message == null) {
      return;
    }
    final cropped = await _captureToastRegion();
    if (!mounted || _message == null) {
      cropped?.dispose();
      return;
    }
    setState(() {
      _capture?.dispose();
      _capture = cropped;
    });
    _timer?.cancel();
    _timer = Timer(duration, clear);
  }

  Future<ui.Image?> _captureToastRegion() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final pillContext = _pillKey.currentContext;
    final self = pillContext?.findRenderObject();
    if (boundary == null ||
        !boundary.hasSize ||
        self is! RenderBox ||
        !self.hasSize) {
      return null;
    }
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale = (dpr / 2).clamp(0.5, dpr);
      final full = await boundary.toImage(pixelRatio: scale);
      final selfTopLeft = self.localToGlobal(Offset.zero);
      final boundaryTopLeft = boundary.localToGlobal(Offset.zero);
      final localOrigin = selfTopLeft - boundaryTopLeft;
      final src = Rect.fromLTWH(
        localOrigin.dx * scale,
        localOrigin.dy * scale,
        self.size.width * scale,
        self.size.height * scale,
      ).intersect(
        Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      );
      if (src.width < 1 || src.height < 1) {
        full.dispose();
        return null;
      }
      final cropped = await _cropImage(full, src);
      full.dispose();
      return cropped;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _cropImage(ui.Image src, Rect srcRect) async {
    final w = srcRect.width.round().clamp(1, src.width);
    final h = srcRect.height.round().clamp(1, src.height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      srcRect,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  final GlobalKey _pillKey = GlobalKey(debugLabel: 'processModeToastPill');

  void clear() {
    _timer?.cancel();
    _timer = null;
    _capture?.dispose();
    _capture = null;
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
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Light frosted pill — blurred capture + cream tint + dark text (图一).
final class ProcessModeToastPill extends StatelessWidget {
  const ProcessModeToastPill({
    super.key,
    required this.message,
    required this.capture,
  });

  final String message;
  final ui.Image? capture;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ProcessModeToast.cornerRadius);
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: capture != null
                ? ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: ProcessModeToast.blurSigma,
                      sigmaY: ProcessModeToast.blurSigma,
                      tileMode: TileMode.clamp,
                    ),
                    child: RawImage(
                      image: capture,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : const ColoredBox(color: Color(0xB3FFFCFA)),
          ),
          const Positioned.fill(
            child: ColoredBox(color: ProcessModeToast.frostFill),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: const Color(0x55FFFFFF), width: 1),
              ),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
