import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_dialog_body.dart';

/// Light alarm prompt chrome: **card-only** Gaussian frost + cream wash.
///
/// Outside the panel stays sharp (scrim only). Card **shrink-wraps** to
/// [WarnDialogBody] (do not expand to max height — that left a huge empty
/// band above the icon).
///
/// Cream frost matches lws-ui `FrostTone.LIGHT`:
/// capture → [ImageFilter.blur] → warm intensity overlay → cream (`#FFFCFA`) wash.
final class WarnFrostShell extends StatefulWidget {
  const WarnFrostShell({
    super.key,
    required this.scope,
    required this.child,
  });

  final CyberBlurBackdropScopeState? scope;
  final Widget child;

  /// Opaque-enough cream when capture is unavailable (`#FFFCFA`).
  static const creamFallback = Color(0xE6FFFCFA);

  /// Cream wash over blur — 奶油白, translucent so page color shows through.
  /// Heavier than intensity overlay alone; lighter than solid white.
  static const creamWash = Color(0xB3FFFCFA);

  /// Warm white overlay from lws-ui LIGHT → EXTREME (`0x50` + warm RGB).
  static Color get warmOverlay => cyberBlurOverlayColor(
        intensity: CyberBlurIntensity.extreme,
        tint: CyberBlurTint.warm,
      );

  /// Gaussian sigma — lws-ui LIGHT / EXTREME dialog frost.
  static const blurSigma = 25.0;

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
      // Keep cream fallback.
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
            // Orange rim above clip (Manual Gas / Feed / Retract style).
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
                            : const ColoredBox(
                                color: WarnFrostShell.creamFallback,
                              ),
                      ),
                      // Warm intensity overlay (lws-ui EXTREME + WARM).
                      Positioned.fill(
                        child: ColoredBox(color: WarnFrostShell.warmOverlay),
                      ),
                      // Cream 奶油白 wash (`#FFFCFA`) — not pure white.
                      const Positioned.fill(
                        child: ColoredBox(color: WarnFrostShell.creamWash),
                      ),
                      widget.child,
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: CyberFrostPanelOutlinePainter(panel.tipRimOutline),
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
