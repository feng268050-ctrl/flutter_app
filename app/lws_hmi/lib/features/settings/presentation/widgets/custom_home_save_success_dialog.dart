import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';

/// Full Custom Home page capture for tip frost (includes metric cards).
///
/// Custom Home editor chrome itself uses WebP stacks (not realtime blur);
/// this scope exists so the save tip can still Gaussian-frost a page shot.
final class CustomHomePageCaptureScope extends InheritedWidget {
  const CustomHomePageCaptureScope({
    super.key,
    required this.boundaryKey,
    required super.child,
  });

  final GlobalKey boundaryKey;

  static CustomHomePageCaptureScope? maybeOf(BuildContext context) {
    return context.findAncestorWidgetOfExactType<CustomHomePageCaptureScope>();
  }

  RenderRepaintBoundary? get renderBoundary {
    final object = boundaryKey.currentContext?.findRenderObject();
    return object is RenderRepaintBoundary ? object : null;
  }

  @override
  bool updateShouldNotify(CustomHomePageCaptureScope oldWidget) =>
      boundaryKey != oldWidget.boundaryKey;
}

/// Frozen page snapshot for dialog frost (lws-ui [FrostBackdropSnapshot]).
final class _PageFrostSnapshot {
  const _PageFrostSnapshot({
    required this.image,
    required this.pixelRatio,
    required this.originGlobal,
  });

  final ui.Image image;
  final double pixelRatio;
  final Offset originGlobal;

  void dispose() => image.dispose();
}

enum _CustomHomeSaveStatus { success, failure }

/// Custom Home save tip = lws-ui [FrostStatusDialog] success mode.
///
/// Design (lws-ui frost prompt): **not** a solid black plate — Gaussian frost
/// of a **page screenshot** under a light tint so the Custom Home cards show
/// through (背景透视). Uses Flutter [RepaintBoundary.toImage] +
/// [ImageFilter.blur] (Weston overlay [BackdropFilter] composites black).
///
/// Orange OK pill is intentional (product primary is blue; Custom Home OK is
/// orange in lws-ui).
Future<void> showCustomHomeSaveSuccessDialog(BuildContext context) =>
    _showCustomHomeSaveStatusDialog(
      context,
      status: _CustomHomeSaveStatus.success,
    );

Future<void> showCustomHomeSaveFailureDialog(BuildContext context) =>
    _showCustomHomeSaveStatusDialog(
      context,
      status: _CustomHomeSaveStatus.failure,
    );

Future<void> _showCustomHomeSaveStatusDialog(
  BuildContext context, {
  required _CustomHomeSaveStatus status,
}) async {
  // Capture *before* the overlay route so the snapshot is the live page
  // (cards + halo), matching FrostBackdropSnapshot.captureSnapshot.
  final snapshot = await _capturePageFrost(context);
  if (!context.mounted) {
    snapshot?.dispose();
    return;
  }

  final panel = CyberPanelBorder(tone: CyberTone.dark);
  Timer? autoDismissTimer;

  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Save succeeded',
      // Transparent: dim is a sibling scrim; frost samples the pre-captured page.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        if (status == _CustomHomeSaveStatus.success &&
            autoDismissTimer == null) {
          autoDismissTimer = Timer(const Duration(milliseconds: 1500), () {
            if (dialogContext.mounted &&
                ModalRoute.of(dialogContext)?.isCurrent == true) {
              Navigator.of(dialogContext).pop();
            }
          });
        }
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Outside stays sharp; only dim it for modal contrast.
              const ColoredBox(color: CyberColors.scrim),
              FadeTransition(
                opacity: animation,
                child: Center(
                  child: _CustomHomeSaveSuccessFrostCard(
                    snapshot: snapshot,
                    panel: panel,
                    status: status,
                    onConfirm: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    autoDismissTimer?.cancel();
    snapshot?.dispose();
  }
}

Future<_PageFrostSnapshot?> _capturePageFrost(BuildContext context) async {
  final pageScope = CustomHomePageCaptureScope.maybeOf(context);
  final blurScope =
      context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
  final boundary = pageScope?.renderBoundary ?? blurScope?.renderBoundary;
  if (boundary == null || !boundary.hasSize) {
    return null;
  }

  // Settle one frame so drag/save layout is stable (lws-ui waits invalidate).
  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) {
    return null;
  }

  try {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Keep the page at native device resolution. The card later takes an
    // exact coordinate crop; downscaling here would shift/scale its backdrop.
    final image = await boundary.toImage(pixelRatio: dpr);
    return _PageFrostSnapshot(
      image: image,
      pixelRatio: dpr,
      originGlobal: boundary.localToGlobal(Offset.zero),
    );
  } catch (_) {
    return null;
  }
}

/// Dark FrostStatus success card: screenshot crop → [ImageFilter.blur] → tint.
final class _CustomHomeSaveSuccessFrostCard extends StatefulWidget {
  const _CustomHomeSaveSuccessFrostCard({
    required this.snapshot,
    required this.panel,
    required this.status,
    required this.onConfirm,
  });

  final _PageFrostSnapshot? snapshot;
  final CyberPanelBorder panel;
  final _CustomHomeSaveStatus status;
  final VoidCallback onConfirm;

  /// lws-ui HIGH dialog frost radius.
  static const blurSigma = 23.0;

  /// CPU fallback radius on the 3× downsampled snapshot. Three box passes
  /// approximate a Gaussian with sigma ≈ 23 without depending on GLES filters.
  static const cpuBlurRadius = 23;

  /// Translucent status wash over the same screenshot Gaussian.
  /// Success reads as white frost; failure reads as red frost.
  Color get frostWash => switch (status) {
        _CustomHomeSaveStatus.success => const Color(0x66FFFCFA),
        _CustomHomeSaveStatus.failure => const Color(0x667A1010),
      };

  Color get fallback => switch (status) {
        _CustomHomeSaveStatus.success => const Color(0xE8FFFCFA),
        _CustomHomeSaveStatus.failure => const Color(0xE89A2424),
      };

  @override
  State<_CustomHomeSaveSuccessFrostCard> createState() =>
      _CustomHomeSaveSuccessFrostCardState();
}

final class _CustomHomeSaveSuccessFrostCardState
    extends State<_CustomHomeSaveSuccessFrostCard> {
  ui.Image? _crop;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_cropToCard());
    });
  }

  @override
  void dispose() {
    _crop?.dispose();
    super.dispose();
  }

  Future<void> _cropToCard() async {
    final snapshot = widget.snapshot;
    final self = _cardKey.currentContext?.findRenderObject();
    if (snapshot == null || self is! RenderBox || !self.hasSize) {
      return;
    }

    final scale = snapshot.pixelRatio;
    final topLeft = self.localToGlobal(Offset.zero) - snapshot.originGlobal;
    final cardRect = Rect.fromLTWH(
      topLeft.dx * scale,
      topLeft.dy * scale,
      self.size.width * scale,
      self.size.height * scale,
    ).intersect(
      Rect.fromLTWH(
        0,
        0,
        snapshot.image.width.toDouble(),
        snapshot.image.height.toDouble(),
      ),
    );
    // Blur a padded source to avoid clamped edges, then cut the exact card
    // rectangle back out. The padded image itself must never be fitted into
    // the card because that scales and offsets the captured page.
    final pad = _CustomHomeSaveSuccessFrostCard.blurSigma * 2;
    final src = Rect.fromLTWH(
      (topLeft.dx - pad) * scale,
      (topLeft.dy - pad) * scale,
      (self.size.width + pad * 2) * scale,
      (self.size.height + pad * 2) * scale,
    ).intersect(
      Rect.fromLTWH(
        0,
        0,
        snapshot.image.width.toDouble(),
        snapshot.image.height.toDouble(),
      ),
    );
    if (src.width < 1 ||
        src.height < 1 ||
        cardRect.width < 1 ||
        cardRect.height < 1) {
      return;
    }

    try {
      final cropped = await _cropAndBlurImage(
        snapshot.image,
        src,
        outputRect: cardRect,
        radius: (_CustomHomeSaveSuccessFrostCard.cpuBlurRadius * scale).round(),
      );
      if (!mounted) {
        cropped.dispose();
        return;
      }
      setState(() {
        _crop?.dispose();
        _crop = cropped;
      });
    } catch (_) {
      // Leave uncropped — still show tinted empty frost, not solid black.
    }
  }

  static Future<ui.Image> _cropAndBlurImage(
    ui.Image src,
    Rect srcRect, {
    required Rect outputRect,
    int radius = _CustomHomeSaveSuccessFrostCard.cpuBlurRadius,
  }) async {
    final left = srcRect.left.floor().clamp(0, src.width - 1);
    final top = srcRect.top.floor().clamp(0, src.height - 1);
    final right = srcRect.right.ceil().clamp(left + 1, src.width);
    final bottom = srcRect.bottom.ceil().clamp(top + 1, src.height);
    final w = right - left;
    final h = bottom - top;
    final data = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw StateError('Custom Home frost snapshot has no RGBA pixels');
    }

    final full = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final pixels = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      final sourceOffset = ((top + y) * src.width + left) * 4;
      final targetOffset = y * w * 4;
      pixels.setRange(
        targetOffset,
        targetOffset + w * 4,
        full,
        sourceOffset,
      );
    }

    // GLES/virgl ignores both display-time and offscreen Skia ImageFilter on
    // this embedder. Blur the downsampled screenshot pixels directly.
    final effectiveRadius = radius.clamp(1, (w < h ? w : h) ~/ 2);
    final scratch = Uint8List(pixels.length);
    for (var pass = 0; pass < 3; pass++) {
      _boxBlurHorizontal(pixels, scratch, w, h, effectiveRadius);
      _boxBlurVertical(scratch, pixels, w, h, effectiveRadius);
    }

    final outputLeft = outputRect.left.floor().clamp(left, right - 1);
    final outputTop = outputRect.top.floor().clamp(top, bottom - 1);
    final outputRight = outputRect.right.ceil().clamp(outputLeft + 1, right);
    final outputBottom = outputRect.bottom.ceil().clamp(outputTop + 1, bottom);
    final outputWidth = outputRight - outputLeft;
    final outputHeight = outputBottom - outputTop;
    final outputPixels = Uint8List(outputWidth * outputHeight * 4);
    for (var y = 0; y < outputHeight; y++) {
      final sourceOffset =
          (((outputTop - top) + y) * w + (outputLeft - left)) * 4;
      final targetOffset = y * outputWidth * 4;
      outputPixels.setRange(
        targetOffset,
        targetOffset + outputWidth * 4,
        pixels,
        sourceOffset,
      );
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(outputPixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: outputWidth,
      height: outputHeight,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  static void _boxBlurHorizontal(
    Uint8List source,
    Uint8List target,
    int width,
    int height,
    int radius,
  ) {
    final window = radius * 2 + 1;
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var channel = 0; channel < 4; channel++) {
        var sum = 0;
        for (var dx = -radius; dx <= radius; dx++) {
          final x = dx < 0 ? 0 : (dx >= width ? width - 1 : dx);
          sum += source[(row + x) * 4 + channel];
        }
        for (var x = 0; x < width; x++) {
          target[(row + x) * 4 + channel] = sum ~/ window;
          final removeX = x - radius < 0 ? 0 : x - radius;
          final addCandidate = x + radius + 1;
          final addX = addCandidate >= width ? width - 1 : addCandidate;
          sum += source[(row + addX) * 4 + channel] -
              source[(row + removeX) * 4 + channel];
        }
      }
    }
  }

  static void _boxBlurVertical(
    Uint8List source,
    Uint8List target,
    int width,
    int height,
    int radius,
  ) {
    final window = radius * 2 + 1;
    for (var x = 0; x < width; x++) {
      for (var channel = 0; channel < 4; channel++) {
        var sum = 0;
        for (var dy = -radius; dy <= radius; dy++) {
          final y = dy < 0 ? 0 : (dy >= height ? height - 1 : dy);
          sum += source[(y * width + x) * 4 + channel];
        }
        for (var y = 0; y < height; y++) {
          target[(y * width + x) * 4 + channel] = sum ~/ window;
          final removeY = y - radius < 0 ? 0 : y - radius;
          final addCandidate = y + radius + 1;
          final addY = addCandidate >= height ? height - 1 : addCandidate;
          sum += source[(addY * width + x) * 4 + channel] -
              source[(removeY * width + x) * 4 + channel];
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.panel.borderRadius;

    return ClipRRect(
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
            // Gaussian is pre-baked into the card's exact
            // native-resolution screenshot rectangle.
            Positioned.fill(
              child: _crop != null
                  ? RawImage(
                      image: _crop,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : ColoredBox(
                      color: widget.snapshot != null
                          ? widget.frostWash
                          : widget.fallback,
                    ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: widget.frostWash,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CyberDimens.contentPadding),
              child: _CustomHomeSaveSuccessBody(
                status: widget.status,
                onConfirm: widget.onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Metrics match `dialog_frost_prompt` + `dialog_frost_body_status` (mode 1).
final class _CustomHomeSaveSuccessBody extends StatelessWidget {
  const _CustomHomeSaveSuccessBody({
    required this.status,
    required this.onConfirm,
  });

  final _CustomHomeSaveStatus status;
  final VoidCallback onConfirm;

  static const _maxWidth = 720.0;
  static const _iconSize = 80.0;
  static const _titleSize = 37.0;
  static const _bodySize = 33.0;
  static const _confirmMinWidth = 500.0;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);
    final success = status == _CustomHomeSaveStatus.success;
    final title = success ? 'Save Succeeded' : 'Save Failed';
    final message = success ? 'Done' : 'Please try again';
    final icon = success
        ? ProcessModeAssets.dialogSuccess
        : ProcessModeAssets.dialogError;
    final textColor =
        success ? const Color(0xFF1A1A1A) : CyberColors.textPrimary;
    final bodyColor =
        success ? const Color(0xCC1A1A1A) : CyberColors.textPrimary;

    return ConstrainedBox(
      key: const ValueKey('custom-home-save-success-dialog'),
      constraints: BoxConstraints(maxWidth: cardW),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: _titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0.02 * _titleSize,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const DecoratedBox(
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
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: Image(
              image: AssetImage(icon),
              width: _iconSize,
              height: _iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: bodyColor,
                fontSize: _bodySize,
                fontWeight: FontWeight.w400,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const DecoratedBox(
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
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: _confirmMinWidth.clamp(200.0, cardW),
                maxWidth: _confirmMinWidth.clamp(200.0, cardW),
              ),
              child: SizedBox(
                width: double.infinity,
                child: _OrangePillButton(
                  label: 'OK',
                  onPressed: onConfirm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _OrangePillButton extends StatelessWidget {
  const _OrangePillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('custom-home-save-success-ok'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        CyberClickSoundRegistry.playClick();
        onPressed();
      },
      child: Container(
        height: CyberDimens.actionButtonMediumHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF853E), Color(0xFFFF5C09)],
          ),
          border: Border.all(color: const Color(0xFFFFB070), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF5C09), blurRadius: 12),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            height: 1,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
