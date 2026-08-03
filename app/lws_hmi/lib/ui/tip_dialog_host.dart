import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Shared tip-dialog chrome presets (lws-ui FrostDialog tones).
///
/// - [showSuccess]: toast-like cream fill, no page透视 (green pass).
/// - [showError]: opaque charcoal (Key switch / red error).
/// - [showDarkPrompt]: lws-ui `FrostTone.DARK` — card Gaussian + dark wash +
///   scrim (Wi‑Fi / register / firmware confirm / …).
/// - [showLightPrompt]: lws-ui `FrostTone.LIGHT` — cream wash over capture
///   (Engineer entry / Laser Enable Important Reminder).
///
/// Startup Self-Check stays on [CyberOverlayHost] realtime frost — not here.
abstract final class TipDialogHost {
  /// Cream “白霜” panel — toast family, no live page透视.
  static Future<T?> showSuccess<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
  }) {
    return CyberOverlayHost.show<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: CyberColors.scrim,
      freezePageBackdrop: false,
      useFakeGlass: true,
      blurTint: CyberBlurTint.warm,
      tone: CyberTone.light,
      constraints: constraints,
      builder: builder,
    );
  }

  /// Opaque charcoal fill — Key switch is off / red error tips.
  static Future<T?> showError<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
  }) {
    return CyberOverlayHost.show<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: CyberColors.scrim,
      freezePageBackdrop: false,
      useFakeGlass: true,
      blurTint: CyberBlurTint.dark,
      tone: CyberTone.dark,
      constraints: constraints,
      builder: builder,
    );
  }

  /// lws-ui dark frost prompt (`dialog_frost_prompt.xml`).
  static Future<T?> showDarkPrompt<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
    String barrierLabel = 'Tip',
  }) {
    return _showCaptureFrost<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      constraints: constraints ??
          BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.62).clamp(320, 720),
            maxHeight: 640,
          ),
      tone: CyberTone.dark,
      wash: cyberBlurOverlayColor(
        intensity: CyberBlurIntensity.high,
        tint: CyberBlurTint.dark,
      ),
      fallback: const Color(0xFF1A1A1E),
    );
  }

  /// lws-ui light cream frost (`dialog_frost_light_overlay.xml`).
  static Future<T?> showLightPrompt<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
    String barrierLabel = 'Tip',
    /// Matches light overlay foreground `paddingTop/Bottom` 20dp.
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(vertical: 20),
  }) {
    return _showCaptureFrost<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      constraints: constraints ??
          const BoxConstraints(
            minWidth: 700,
            maxWidth: 700,
            minHeight: 480,
            maxHeight: 680,
          ),
      tone: CyberTone.light,
      wash: const Color(0xD9FFFCFA),
      fallback: const Color(0xFFFFFCFA),
      padding: padding,
    );
  }

  static Future<T?> _showCaptureFrost<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    required bool barrierDismissible,
    required String barrierLabel,
    required BoxConstraints constraints,
    required CyberTone tone,
    required Color wash,
    required Color fallback,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(CyberDimens.contentPadding),
  }) {
    final scope = context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
    final panel = CyberPanelBorder(tone: tone);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: barrierDismissible
                    ? () => Navigator.of(dialogContext).maybePop()
                    : null,
                child: const ColoredBox(color: CyberColors.scrim),
              ),
              FadeTransition(
                opacity: animation,
                child: Center(
                  child: ConstrainedBox(
                    constraints: constraints,
                    child: _TipFrostCard(
                      scope: scope,
                      panel: panel,
                      wash: wash,
                      fallback: fallback,
                      padding: padding,
                      child: builder(dialogContext),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Card-local Gaussian frost (Flutter [ImageFilter.blur]) + tint wash.
///
/// Overlay routes sit outside [CyberBlurBackdropScope], so capture is resolved
/// from the *caller* scope — same path as warn / former Operation-failed tips.
final class _TipFrostCard extends StatefulWidget {
  const _TipFrostCard({
    required this.scope,
    required this.panel,
    required this.wash,
    required this.fallback,
    required this.child,
    this.padding = const EdgeInsets.all(CyberDimens.contentPadding),
  });

  final CyberBlurBackdropScopeState? scope;
  final CyberPanelBorder panel;
  final Color wash;
  final Color fallback;
  final Widget child;
  final EdgeInsetsGeometry padding;

  static const blurSigma = 23.0;

  @override
  State<_TipFrostCard> createState() => _TipFrostCardState();
}

final class _TipFrostCardState extends State<_TipFrostCard> {
  ui.Image? _capture;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sample());
    });
  }

  @override
  void dispose() {
    _capture?.dispose();
    super.dispose();
  }

  Future<void> _sample() async {
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
      // Keep solid fallback.
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
    final radius = widget.panel.borderRadius;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tightWidth = constraints.maxWidth.isFinite &&
            constraints.maxWidth < double.infinity;
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: tightWidth ? constraints.maxWidth : 0,
            maxWidth: constraints.maxWidth,
            minHeight: constraints.minHeight,
            maxHeight: constraints.maxHeight,
          ),
          child: ClipRRect(
            key: _cardKey,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: widget.panel.flatBorderColor,
                  width: widget.panel.width,
                ),
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: _capture != null
                        ? ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: _TipFrostCard.blurSigma,
                              sigmaY: _TipFrostCard.blurSigma,
                              tileMode: TileMode.clamp,
                            ),
                            child: RawImage(
                              image: _capture,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : ColoredBox(color: widget.fallback),
                  ),
                  Positioned.fill(
                    child: ColoredBox(color: widget.wash),
                  ),
                  Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// lws-ui `frost_divider` gradient hairline used between tip sections.
class TipFrostDivider extends StatelessWidget {
  const TipFrostDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x0068686C),
            CyberColors.dividerCenter,
            Color(0x0068686C),
          ],
        ),
      ),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}
