import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Light alarm prompt chrome: **card-only** Gaussian frost + opaque cream.
///
/// Outside the panel stays sharp (scrim only). Capture root comes from the
/// caller’s [CyberBlurBackdropScope] (dialog routes sit outside the scope).
final class WarnFrostShell extends StatefulWidget {
  const WarnFrostShell({
    super.key,
    required this.scope,
    required this.child,
    this.maxWidth = 560,
  });

  final CyberBlurBackdropScopeState? scope;
  final Widget child;
  final double maxWidth;

  /// Cream fallback when capture is unavailable.
  static const creamFallback = Color(0xFFFFFCFA);

  /// Cream wash over card-local Gaussian (blur layer itself is opacity 1.0).
  static const creamWash = Color(0xD9FFFCFA);

  /// Gaussian sigma (~lws-ui HIGH dialog frost).
  static const blurSigma = 23.0;

  @override
  State<WarnFrostShell> createState() => _WarnFrostShellState();
}

final class _WarnFrostShellState extends State<WarnFrostShell> {
  ui.Image? _capture;
  final GlobalKey _cardKey = GlobalKey();

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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outside: dim only — no blur.
        const ColoredBox(color: CyberColors.scrim),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: ClipRRect(
              key: _cardKey,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: panel.flatBorderColor,
                    width: panel.width,
                  ),
                ),
                child: Stack(
                  children: [
                    // Card-local Gaussian (opacity 1.0).
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
                          : const ColoredBox(color: WarnFrostShell.creamFallback),
                    ),
                    const Positioned.fill(
                      child: ColoredBox(color: WarnFrostShell.creamWash),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.all(CyberDimens.contentPadding),
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
