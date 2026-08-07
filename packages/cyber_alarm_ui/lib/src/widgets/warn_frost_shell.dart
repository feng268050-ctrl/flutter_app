import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_alarm_ui/src/widgets/warn_dialog_metrics.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Light alarm prompt chrome — lws-ui `FrostTone.LIGHT` cream **glass**.
///
/// Outside the panel stays sharp (scrim only). Card **shrink-wraps** to
/// [WarnDialogBody] (do not expand to max height — that left a huge empty
/// band above the icon).
///
/// Layer stack (back → front), matching `dialog_frost_light_overlay` /
/// `WorkStatusDialogBackdropDrawable` / EXTREME+WARM / shell frost:
/// 1. Captured page crop → Gaussian EXTREME (σ 25), or translucent light fill
/// 2. Warm-yellow → white → warm-yellow translucent backdrop gradient
/// 3. Warm intensity overlay (`#50FFFFFF`)
/// 4. Thin white shell-frost veil
/// 5. Foreground content (unblurred)
/// 6. Light-tone gradient rim above the clip
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

  /// Gaussian sigma — lws-ui LIGHT / EXTREME dialog frost.
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
  ui.Image? _capture;
  final GlobalKey _cardKey = GlobalKey();
  Size? _lastSampledSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sampleCard());
    });
  }

  @override
  void dispose() {
    _capture?.dispose();
    super.dispose();
  }

  Future<void> _sampleCard() async {
    final boundary = widget.scope?.renderBoundary;
    final self = _cardKey.currentContext?.findRenderObject();
    if (boundary == null ||
        !boundary.hasSize ||
        self is! RenderBox ||
        !self.hasSize) {
      return;
    }
    final size = self.size;
    if (_lastSampledSize == size && _capture != null) {
      return;
    }
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale = (dpr / 3).clamp(0.25, dpr);
      final full = await boundary.toImage(pixelRatio: scale);
      if (!mounted) {
        full.dispose();
        return;
      }
      final origin =
          self.localToGlobal(Offset.zero) - boundary.localToGlobal(Offset.zero);
      final src = Rect.fromLTWH(
        origin.dx * scale,
        origin.dy * scale,
        self.size.width * scale,
        self.size.height * scale,
      ).intersect(
        Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      );
      if (src.width < 1 || src.height < 1) {
        full.dispose();
        return;
      }
      final cropped = await _crop(full, src);
      full.dispose();
      if (!mounted) {
        cropped.dispose();
        return;
      }
      setState(() {
        _capture?.dispose();
        _capture = cropped;
        _lastSampledSize = size;
      });
    } catch (_) {
      // Keep translucent light-fill fallback.
    }
  }

  static Future<ui.Image> _crop(ui.Image src, Rect srcRect) async {
    final w = srcRect.width.round().clamp(1, src.width);
    final h = srcRect.height.round().clamp(1, src.height);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
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

  @override
  Widget build(BuildContext context) {
    final panel = CyberPanelBorder(tone: CyberTone.light);
    final radius = panel.borderRadius;
    final maxW =
        MediaQuery.sizeOf(context).width * WarnDialogMetrics.maxWidthFraction;
    final maxH = WarnDialogMetrics.maxCardHeight(context);
    final lightRim = CyberPanelOutline(
      style: CyberPanelOutlineStyle.frostGradient,
      tone: CyberTone.light,
      width: panel.width,
      cornerRadius: panel.cornerRadius,
    );

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
                      // 1. Blurred page crop (透视) or translucent light fill.
                      Positioned.fill(
                        child: _capture != null
                            ? ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: WarnFrostShell.blurSigma,
                                  sigmaY: WarnFrostShell.blurSigma,
                                  tileMode: TileMode.clamp,
                                ),
                                child: RawImage(
                                  image: _capture,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: WarnFrostShell.lightFillFallback,
                                ),
                              ),
                      ),
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
                // 6. Light-tone gradient rim above clip.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: CyberFrostPanelOutlinePainter(lightRim),
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
