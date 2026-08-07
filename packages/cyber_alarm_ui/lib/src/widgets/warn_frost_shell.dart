import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_alarm_ui/src/widgets/warn_dialog_metrics.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Light alarm prompt chrome — lws-ui `FrostTone.LIGHT` cream **glass**.
///
/// Outside the panel stays sharp (scrim only). Card **shrink-wraps** to
/// [WarnDialogBody] (do not expand to max height — that left a huge empty
/// band above the icon).
///
/// Layer stack (back → front), matching `dialog_frost_light_overlay` /
/// `FrostPanelShell` / EXTREME+WARM / shell frost:
/// 1. Full-page capture with **baked** Gaussian EXTREME (σ 25), matrix-aligned
///    into the card (lws-ui ImageView + Matrix) — crop-then-blur hid透视
/// 2. Warm-yellow → white → warm-yellow translucent backdrop gradient
/// 3. Warm intensity overlay (`#50FFFFFF`)
/// 4. Thin white shell-frost veil
/// 5. Foreground content (unblurred)
/// 6. 1px opaque black container rim above the clip
///
/// Gaussian is baked into the [ui.Image] (same as [CyberBackdropBlur]) — live
/// [ImageFiltered] often fails to composite on flutter-pi / soft GL.
final class WarnFrostShell extends StatefulWidget {
  const WarnFrostShell({
    super.key,
    required this.scope,
    required this.child,
  });

  final CyberBlurBackdropScopeState? scope;
  final Widget child;

  /// Warm white overlay from lws-ui LIGHT → EXTREME (`0x50` + warm RGB).
  static Color get warmOverlay => cyberBlurOverlayColor(
        intensity: CyberBlurIntensity.extreme,
        tint: CyberBlurTint.warm,
      );

  /// Gaussian sigma — lws-ui LIGHT / EXTREME dialog frost (logical px).
  static const blurSigma = 25.0;

  /// lws-ui `WorkStatusDialogBackdropDrawable` vertical stops.
  static const backdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      CyberColors.lightWarnBackdropEdge,
      CyberColors.lightWarnBackdropBlend,
      CyberColors.lightWarnBackdropCenter,
      CyberColors.lightWarnBackdropBlend,
      CyberColors.lightWarnBackdropEdge,
    ],
    stops: [0.0, 0.32, 0.5, 0.68, 1.0],
  );

  /// lws-ui `WorkStatusDialogShellFrostDrawable` vertical stops.
  static const shellFrostGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      CyberColors.lightShellFrostEdge,
      CyberColors.lightShellFrostCenter,
      CyberColors.lightShellFrostEdge,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Fallback when capture is unavailable — translucent light fill (not opaque cream).
  static const lightFillFallback = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      CyberColors.lightFillTop,
      CyberColors.lightFillMid,
      CyberColors.lightFillBottom,
    ],
  );

  @override
  State<WarnFrostShell> createState() => _WarnFrostShellState();
}

final class _WarnFrostShellState extends State<WarnFrostShell> {
  /// Pre-blurred **full page** — painted with matrix offset into the card.
  ui.Image? _blurred;
  Size? _pageLogicalSize;
  Offset _cardOriginInPage = Offset.zero;
  final GlobalKey _cardKey = GlobalKey();
  Size? _lastSampledSize;
  int _captureRetryCount = 0;
  bool _capturePending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sampleCard());
    });
  }

  @override
  void dispose() {
    _blurred?.dispose();
    super.dispose();
  }

  Future<void> _sampleCard() async {
    if (_capturePending) {
      return;
    }
    final scope = widget.scope;
    final self = _cardKey.currentContext?.findRenderObject();
    if (scope == null) {
      debugPrint('warn-frost: sample skip scope=null');
      return;
    }
    if (self is! RenderBox || !self.hasSize) {
      debugPrint('warn-frost: sample skip card-unready');
      return;
    }
    // Prefer full page (activity content) — surface is wallpaper-only.
    final boundary = scope.renderBoundaryFor(CyberBlurCaptureTarget.currentPage) ??
        scope.renderBoundary;
    if (boundary == null || !boundary.hasSize) {
      debugPrint('warn-frost: sample skip boundary-unready');
      return;
    }
    final size = self.size;
    if (_lastSampledSize == size && _blurred != null) {
      return;
    }

    _capturePending = true;
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      // Match lws-ui BLUR_SCALE_FACTOR ≈ 3 (capture at ~1/3, paint scaled up).
      final scale = (dpr / 3).clamp(0.25, dpr);
      final full = await boundary.toImage(pixelRatio: scale);
      if (!mounted) {
        full.dispose();
        return;
      }

      final origin =
          self.localToGlobal(Offset.zero) - boundary.localToGlobal(Offset.zero);
      final pageLogical = boundary.size;

      final mean = await _meanRgb(full);
      if (mean < 2.0) {
        full.dispose();
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _capturePending = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_sampleCard());
          });
          return;
        }
        debugPrint('warn-frost: capture all-black mean=$mean');
        return;
      }

      // Bake Gaussian on the **full** page so card edges bleed surrounding UI
      // (lws-ui FrostPanelShell matrix snapshot — not crop-then-blur).
      final blurred = await _blurImage(
        full,
        sigmaX: WarnFrostShell.blurSigma * scale,
        sigmaY: WarnFrostShell.blurSigma * scale,
      );
      full.dispose();
      if (!mounted) {
        blurred.dispose();
        return;
      }

      debugPrint(
        'warn-frost: capture ok page=${pageLogical.width.toStringAsFixed(0)}x'
        '${pageLogical.height.toStringAsFixed(0)} '
        'card=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)} '
        'mean=${mean.toStringAsFixed(1)} scale=${scale.toStringAsFixed(2)} '
        'origin=${origin.dx.toStringAsFixed(0)},${origin.dy.toStringAsFixed(0)} '
        'baked=${blurred.width}x${blurred.height} fullPage=1',
      );

      setState(() {
        _blurred?.dispose();
        _blurred = blurred;
        _pageLogicalSize = pageLogical;
        _cardOriginInPage = origin;
        _lastSampledSize = size;
        _captureRetryCount = 0;
      });
    } catch (e) {
      debugPrint('warn-frost: capture failed: $e');
    } finally {
      _capturePending = false;
    }
  }

  /// Same bake path as [CyberBlurBackdropScope] / [CyberBackdropBlur].
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

  static Future<double> _meanRgb(ui.Image image) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null || bytes.lengthInBytes < 4) {
      return 0;
    }
    final bd = bytes.buffer.asUint8List();
    var sum = 0;
    var n = 0;
    // Sparse sample — enough to reject all-black wallpaper race.
    for (var i = 0; i + 2 < bd.length; i += 64) {
      sum += bd[i] + bd[i + 1] + bd[i + 2];
      n += 3;
    }
    return n == 0 ? 0 : sum / n;
  }

  Widget _backdropLayer() {
    final blurred = _blurred;
    final page = _pageLogicalSize;
    if (blurred == null || page == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: WarnFrostShell.lightFillFallback,
        ),
      );
    }
    // lws-ui: ImageView scaleType=matrix — full blurred page, translated so the
    // card window shows the matching region (surroundings bleed into glass).
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -_cardOriginInPage.dx,
            top: -_cardOriginInPage.dy,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = CyberPanelBorder(tone: CyberTone.light);
    final radius = panel.borderRadius;
    final maxW =
        MediaQuery.sizeOf(context).width * WarnDialogMetrics.maxWidthFraction;
    final maxH = WarnDialogMetrics.maxCardHeight(context);
    // 1px opaque black — above clip so the stroke is not cropped away.
    final containerRim = panel.creamDialogRimOutline;

    // Re-sample if layout settled to a new card size (first frame often empty).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _cardKey.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          _lastSampledSize != box.size) {
        unawaited(_sampleCard());
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: CyberColors.scrim),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                ClipRRect(
                  key: _cardKey,
                  borderRadius: radius,
                  clipBehavior: Clip.antiAlias,
                  // [StackFit.loose] shrink-wraps to [WarnDialogBody] — never
                  // expand to maxH (passthrough caused the huge top gap).
                  child: Stack(
                    fit: StackFit.loose,
                    children: [
                      // 1. Full-page baked blur, matrix-aligned (透视).
                      Positioned.fill(child: _backdropLayer()),
                      // 2. Warm-yellow cream glass wash (not opaque cream plate).
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: WarnFrostShell.backdropGradient,
                          ),
                        ),
                      ),
                      // 3. EXTREME + WARM intensity overlay.
                      Positioned.fill(
                        child: ColoredBox(color: WarnFrostShell.warmOverlay),
                      ),
                      // 4. Thin white shell-frost veil.
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: WarnFrostShell.shellFrostGradient,
                          ),
                        ),
                      ),
                      // 5. Foreground content.
                      widget.child,
                    ],
                  ),
                ),
                // 6. 1px opaque black rim above clip.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: CyberFrostPanelOutlinePainter(containerRim),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
