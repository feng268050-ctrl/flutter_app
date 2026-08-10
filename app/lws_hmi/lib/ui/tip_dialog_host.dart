import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Product tip / prompt dialogs.
///
/// - [showSuccess] / [showError] / [showDarkPrompt]: Startup Self-Check frost
///   (transparent barrier, realtime dark wallpaper blur).
/// - [showLightPrompt]: lws-ui LIGHT cream glass (Engineer tip / Laser Enable
///   Important Reminder) — full-page baked Gaussian + matrix 透视.
///
/// **Excluded:** warn/alarm dialogs (`cyber_alarm_ui` WarnFrostShell) stay on
/// their own path (same LIGHT glass recipe).
abstract final class TipDialogHost {
  /// Shared Startup Self-Check backdrop (see [showBootSelfCheckDialog]).
  static Future<T?> _showSelfCheckFrost<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
  }) {
    return CyberOverlayHost.show<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.transparent,
      freezePageBackdrop: false,
      useFakeGlass: false,
      sampleMode: CyberBlurSampleMode.realtime,
      intensity: CyberBlurIntensity.high,
      blurTint: CyberBlurTint.dark,
      tone: CyberTone.dark,
      constraints: constraints,
      builder: builder,
    );
  }

  /// Pass / toast tip — Self-Check dark frost.
  static Future<T?> showSuccess<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
  }) {
    return _showSelfCheckFrost<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      constraints: constraints,
    );
  }

  /// Error tip — Self-Check dark frost.
  static Future<T?> showError<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
  }) {
    return _showSelfCheckFrost<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      constraints: constraints,
    );
  }

  /// Confirm / guidance prompt (Wi‑Fi, register, firmware, …).
  static Future<T?> showDarkPrompt<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    BoxConstraints? constraints,
    String barrierLabel = 'Tip',
  }) {
    assert(() {
      // ignore: unnecessary_statements
      barrierLabel;
      return true;
    }());
    return _showSelfCheckFrost<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      constraints: constraints ??
          BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.62).clamp(320, 720),
            maxHeight: (MediaQuery.sizeOf(context).height * 0.85).clamp(320, 720),
          ),
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
    final scope =
        context.findAncestorStateOfType<CyberBlurBackdropScopeState>() ??
            _findBlurScope(context);

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
                    constraints: constraints ??
                        BoxConstraints(
                          minWidth: 700,
                          maxWidth: 700,
                          minHeight: 480,
                          maxHeight:
                              (MediaQuery.sizeOf(dialogContext).height * 0.85)
                                  .clamp(480, 720),
                        ),
                    child: _LightCreamFrostCard(
                      scope: scope,
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

/// Prefer the blur scope on the *current* navigator route (top page).
///
/// Same rationale as warn presentation: Home stays under pushed routes, so the
/// first DFS hit is the wrong wallpaper for Engineer / Settings tips.
CyberBlurBackdropScopeState? _findBlurScope(BuildContext root) {
  CyberBlurBackdropScopeState? last;
  CyberBlurBackdropScopeState? onCurrentRoute;
  void visit(Element element) {
    if (element is StatefulElement &&
        element.state is CyberBlurBackdropScopeState) {
      final state = element.state as CyberBlurBackdropScopeState;
      last = state;
      final route = ModalRoute.of(element);
      if (route != null && route.isCurrent) {
        onCurrentRoute = state;
      }
    }
    element.visitChildren(visit);
  }

  root.visitChildElements(visit);
  return onCurrentRoute ?? last;
}

/// LIGHT cream glass card — same recipe as `WarnFrostShell` / lws-ui
/// `FrostPanelShell`: full-page baked Gaussian + matrix 透视 + warm wash.
final class _LightCreamFrostCard extends StatefulWidget {
  const _LightCreamFrostCard({
    required this.scope,
    required this.child,
    this.padding = const EdgeInsets.all(CyberDimens.contentPadding),
  });

  final CyberBlurBackdropScopeState? scope;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Warm white overlay from lws-ui LIGHT → EXTREME (`0x50` + warm RGB).
  static Color get warmOverlay => cyberBlurOverlayColor(
        intensity: CyberBlurIntensity.extreme,
        tint: CyberBlurTint.warm,
      );

  /// Gaussian sigma — lws-ui LIGHT / EXTREME dialog frost (logical px).
  static const blurSigma = 25.0;

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
  State<_LightCreamFrostCard> createState() => _LightCreamFrostCardState();
}

final class _LightCreamFrostCardState extends State<_LightCreamFrostCard> {
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
      unawaited(_sample());
    });
  }

  @override
  void dispose() {
    _blurred?.dispose();
    super.dispose();
  }

  Future<void> _sample() async {
    if (_capturePending) {
      return;
    }
    final scope = widget.scope;
    final self = _cardKey.currentContext?.findRenderObject();
    if (scope == null) {
      debugPrint('tip-frost: sample skip scope=null');
      return;
    }
    if (self is! RenderBox || !self.hasSize) {
      debugPrint('tip-frost: sample skip card-unready');
      return;
    }
    final boundary = scope.renderBoundaryFor(CyberBlurCaptureTarget.currentPage) ??
        scope.renderBoundary;
    if (boundary == null || !boundary.hasSize) {
      debugPrint('tip-frost: sample skip boundary-unready');
      return;
    }
    final size = self.size;
    if (_lastSampledSize == size && _blurred != null) {
      return;
    }

    _capturePending = true;
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
      final pageLogical = boundary.size;

      final mean = await _meanRgb(full);
      if (mean < 2.0) {
        full.dispose();
        if (_captureRetryCount < 12) {
          _captureRetryCount++;
          _capturePending = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_sample());
          });
          return;
        }
        debugPrint('tip-frost: capture all-black mean=$mean');
        return;
      }

      final blurred = await _blurImage(
        full,
        sigmaX: _LightCreamFrostCard.blurSigma * scale,
        sigmaY: _LightCreamFrostCard.blurSigma * scale,
      );
      full.dispose();
      if (!mounted) {
        blurred.dispose();
        return;
      }

      debugPrint(
        'tip-frost: capture ok page=${pageLogical.width.toStringAsFixed(0)}x'
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
      debugPrint('tip-frost: capture failed: $e');
    } finally {
      _capturePending = false;
    }
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

  static Future<double> _meanRgb(ui.Image image) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null || bytes.lengthInBytes < 4) {
      return 0;
    }
    final bd = bytes.buffer.asUint8List();
    var sum = 0;
    var n = 0;
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
          gradient: _LightCreamFrostCard.lightFillFallback,
        ),
      );
    }
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
    // 1px opaque black — above clip so the stroke is not cropped away.
    final containerRim = panel.creamDialogRimOutline;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _cardKey.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          _lastSampledSize != box.size) {
        unawaited(_sample());
      }
    });

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
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              ClipRRect(
                key: _cardKey,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Positioned.fill(child: _backdropLayer()),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _LightCreamFrostCard.backdropGradient,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ColoredBox(
                        color: _LightCreamFrostCard.warmOverlay,
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _LightCreamFrostCard.shellFrostGradient,
                        ),
                      ),
                    ),
                    Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CyberFrostPanelOutlinePainter(containerRim),
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

/// lws-ui `frost_divider` — center hairline fading to transparent edges.
///
/// Alias of [CyberFrostDivider] for tip / Safety Tips call sites.
typedef TipFrostDivider = CyberFrostDivider;
