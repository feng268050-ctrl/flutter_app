import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Quick Mode Laser Enable frost — lws-ui [BlurUtils.showBlurView] parity.
///
/// On arm (laser enable success):
/// 1. Immediately lock pointers and show a mist veil (plus interim live blur).
/// 2. Queue one low-res offscreen Gaussian snapshot (σ=15) per region.
/// 3. Paste the snapshot as background and hide the live child (fog placeholder).
///
/// On disarm the snapshot is dropped and the child returns.
///
/// Engineer mode must **not** use this widget (no BlurUtils path there).
///
/// Uses [RepaintBoundary.toImage] + [ImageFiltered]/[RawImage] — **not** live
/// [BackdropFilter] (unsafe with Record Work / GStreamer on Weston+Mali).
final class LaserEnableRegionFrost extends StatefulWidget {
  const LaserEnableRegionFrost({
    super.key,
    required this.armed,
    required this.child,
    this.borderRadius,
  });

  final bool armed;
  final Widget child;
  final BorderRadius? borderRadius;

  /// lws-ui `BlurUtils.blurView(..., 15)`.
  static const double sigma = 15;

  /// Capture scale divisor vs device pixel ratio (lower = faster readback).
  static const double captureScaleFactor = 4;

  /// Soft mist — shown immediately on arm, kept over the frozen plate.
  static const Color tint = Color(0x28101012);

  /// Serialize Mali `toImage` across all frost regions (avoids multi-second stalls).
  static Future<void> _captureChain = Future<void>.value();

  static Future<T> _runCaptureExclusive<T>(Future<T> Function() body) {
    final prior = _captureChain;
    late final Completer<void> gate;
    gate = Completer<void>();
    _captureChain = gate.future;
    return prior.then((_) => body()).whenComplete(() {
      if (!gate.isCompleted) {
        gate.complete();
      }
    });
  }

  @visibleForTesting
  static void debugResetCaptureQueue() {
    _captureChain = Future<void>.value();
  }

  @override
  State<LaserEnableRegionFrost> createState() => _LaserEnableRegionFrostState();
}

final class _LaserEnableRegionFrostState extends State<LaserEnableRegionFrost> {
  final GlobalKey _boundaryKey =
      GlobalKey(debugLabel: 'laserEnableRegionFrost');

  ui.Image? _snapshot;
  var _captureGen = 0;
  var _hideChild = false;

  ui.ImageFilter get _blur => ui.ImageFilter.blur(
        sigmaX: LaserEnableRegionFrost.sigma,
        sigmaY: LaserEnableRegionFrost.sigma,
        tileMode: TileMode.decal,
      );

  @override
  void initState() {
    super.initState();
    if (widget.armed) {
      _scheduleCapture();
    }
  }

  @override
  void didUpdateWidget(covariant LaserEnableRegionFrost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.armed && !oldWidget.armed) {
      _scheduleCapture();
    } else if (!widget.armed && oldWidget.armed) {
      _clearSnapshot();
    }
  }

  @override
  void dispose() {
    _captureGen++;
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  void _clearSnapshot() {
    _captureGen++;
    _snapshot?.dispose();
    _snapshot = null;
    _hideChild = false;
  }

  void _scheduleCapture() {
    final gen = ++_captureGen;
    _hideChild = false;
    _snapshot?.dispose();
    _snapshot = null;
    // One frame so the still-visible child is laid out, then queue capture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_capture(gen, attempt: 0));
    });
  }

  Future<void> _capture(int gen, {required int attempt}) async {
    if (!mounted || gen != _captureGen || !widget.armed) {
      return;
    }
    await LaserEnableRegionFrost._runCaptureExclusive(() async {
      if (!mounted || gen != _captureGen || !widget.armed) {
        return;
      }
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        if (attempt < 2 && mounted && gen == _captureGen && widget.armed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_capture(gen, attempt: attempt + 1));
          });
        }
        return;
      }
      try {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final scale =
            (dpr / LaserEnableRegionFrost.captureScaleFactor).clamp(0.35, dpr);
        final image = await boundary.toImage(pixelRatio: scale);
        if (!mounted || gen != _captureGen || !widget.armed) {
          image.dispose();
          return;
        }
        setState(() {
          _snapshot?.dispose();
          _snapshot = image;
          _hideChild = true;
        });
      } catch (_) {
        // Keep interim live blur + veil; pointers already absorbed.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.armed) {
      return widget.child;
    }

    Widget stack = Stack(
      fit: StackFit.passthrough,
      children: [
        // Interim: live ImageFiltered blur (instant). After snapshot: hide
        // live controls but keep layout (lws-ui wheelView INVISIBLE).
        if (!_hideChild)
          ImageFiltered(
            imageFilter: _blur,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: widget.child,
            ),
          )
        else
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            maintainInteractivity: false,
            child: widget.child,
          ),
        if (_snapshot != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: _blur,
              child: RawImage(
                image: _snapshot,
                fit: BoxFit.fill,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        // Immediate mist lock (before snapshot finishes).
        const Positioned.fill(
          child: ColoredBox(color: LaserEnableRegionFrost.tint),
        ),
      ],
    );

    stack = widget.borderRadius != null
        ? ClipRRect(borderRadius: widget.borderRadius!, child: stack)
        : ClipRect(child: stack);

    return AbsorbPointer(
      key: const ValueKey('laser-enable-region-frost'),
      child: stack,
    );
  }
}
