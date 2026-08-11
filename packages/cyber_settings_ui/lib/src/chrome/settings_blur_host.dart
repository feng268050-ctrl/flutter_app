import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Default page Gaussian between wallpaper and Settings chrome (product / OS).
const kSettingsPageBlurSigma = 30.0;

/// Declares page chrome — descendant frosted panels use tint/rim only.
class SettingsPageBackdropBlur extends InheritedWidget {
  const SettingsPageBackdropBlur({
    super.key,
    required this.sigma,
    required super.child,
  });

  final double sigma;

  static SettingsPageBackdropBlur? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SettingsPageBackdropBlur>();
  }

  @override
  bool updateShouldNotify(SettingsPageBackdropBlur oldWidget) =>
      oldWidget.sigma != sigma;
}

/// Owns the single σ bake for an App (mount above [Navigator]).
///
/// Captures sharp wallpaper via [CyberBlurBackdropTarget], bakes once, then
/// publishes through [SettingsSharedBlurPlate]. Route chrome blits that image
/// with [SettingsSharedBlurMask] — no per-page re-capture.
///
/// Wallpaper path / presets stay in `cyber_hal` [Wallpaper]; pass
/// [rebakeListenable] (e.g. `wallpaper.listenable`) or [rebakeKey] (path) to
/// invalidate after a preset change without putting `ui.Image` in HAL.
class SettingsBlurHost extends StatefulWidget {
  const SettingsBlurHost({
    super.key,
    required this.child,
    required this.backdropBuilder,
    this.blurSigma = kSettingsPageBlurSigma,
    this.rebakeListenable,
    this.rebakeKey,
  });

  final Widget child;
  final double blurSigma;

  /// Sharp wallpaper (and optional dim) for capture + live fallback.
  final Widget Function() backdropBuilder;

  /// When this notifies (e.g. HAL [Wallpaper.listenable]), drop plate and rebake.
  final Listenable? rebakeListenable;

  /// When this identity changes (e.g. `wallpaper.activePath`), rebake.
  final Object? rebakeKey;

  static const captureScaleFactor = 3.0;

  @override
  State<SettingsBlurHost> createState() => _SettingsBlurHostState();
}

class _SettingsBlurHostState extends State<SettingsBlurHost> {
  final SettingsSharedBlurPlateController _plate =
      SettingsSharedBlurPlateController();

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CyberBlurBackdropScope(
      child: SettingsPageBackdropBlur(
        sigma: widget.blurSigma,
        child: SettingsSharedBlurPlate(
          controller: _plate,
          backdropBuilder: widget.backdropBuilder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CyberBlurBackdropTarget(
                  child: widget.backdropBuilder(),
                ),
              ),
              _SettingsBlurBakePublisher(
                blurSigma: widget.blurSigma,
                controller: _plate,
                rebakeListenable: widget.rebakeListenable,
                rebakeKey: widget.rebakeKey,
              ),
              Positioned.fill(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared baked σ plate — one owner ([SettingsBlurHost]), many route blitters.
class SettingsSharedBlurPlateController extends ChangeNotifier {
  ui.Image? _image;
  double blurSigma = kSettingsPageBlurSigma;

  ui.Image? get image => _image;

  void accept(ui.Image owned, {required double sigma}) {
    final previous = _image;
    _image = owned;
    blurSigma = sigma;
    previous?.dispose();
    notifyListeners();
  }

  void clear() {
    final previous = _image;
    _image = null;
    previous?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

class SettingsSharedBlurPlate
    extends InheritedNotifier<SettingsSharedBlurPlateController> {
  const SettingsSharedBlurPlate({
    super.key,
    required SettingsSharedBlurPlateController controller,
    required this.backdropBuilder,
    required super.child,
  }) : super(notifier: controller);

  final Widget Function() backdropBuilder;

  static SettingsSharedBlurPlateController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SettingsSharedBlurPlate>()
        ?.notifier;
  }

  static SettingsSharedBlurPlate? maybeWidgetOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsSharedBlurPlate>();
  }

  @override
  bool updateShouldNotify(SettingsSharedBlurPlate oldWidget) {
    return super.updateShouldNotify(oldWidget) ||
        backdropBuilder != oldWidget.backdropBuilder;
  }
}

class _SettingsBlurBakePublisher extends StatefulWidget {
  const _SettingsBlurBakePublisher({
    required this.blurSigma,
    required this.controller,
    this.rebakeListenable,
    this.rebakeKey,
  });

  final double blurSigma;
  final SettingsSharedBlurPlateController controller;
  final Listenable? rebakeListenable;
  final Object? rebakeKey;

  @override
  State<_SettingsBlurBakePublisher> createState() =>
      _SettingsBlurBakePublisherState();
}

class _SettingsBlurBakePublisherState extends State<_SettingsBlurBakePublisher> {
  bool _bakePending = false;
  int _bakeGen = 0;
  int _bakeRetries = 0;
  VoidCallback? _rebakeListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleBake();
  }

  @override
  void didUpdateWidget(covariant _SettingsBlurBakePublisher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rebakeListenable != widget.rebakeListenable) {
      oldWidget.rebakeListenable?.removeListener(_onRebakeSignal);
      _attachRebakeListener();
    }
    if (oldWidget.blurSigma != widget.blurSigma ||
        oldWidget.rebakeKey != widget.rebakeKey) {
      _requestRebake();
    }
  }

  @override
  void initState() {
    super.initState();
    _attachRebakeListener();
  }

  void _attachRebakeListener() {
    _rebakeListener ??= _onRebakeSignal;
    widget.rebakeListenable?.addListener(_rebakeListener!);
  }

  void _onRebakeSignal() => _requestRebake();

  void _requestRebake() {
    if (!mounted) {
      return;
    }
    CyberBlurBackdropScope.maybeOf(context)?.invalidateFullCapture();
    widget.controller.clear();
    _bakeRetries = 0;
    _scheduleBake(force: true);
  }

  @override
  void dispose() {
    _bakeGen++;
    if (_rebakeListener != null) {
      widget.rebakeListenable?.removeListener(_rebakeListener!);
    }
    super.dispose();
  }

  void _scheduleBake({int settlePasses = 4, bool force = false}) {
    if (_bakePending || !mounted) {
      return;
    }
    if (!force && widget.controller.image != null) {
      return;
    }
    final gen = ++_bakeGen;
    _bakePending = true;
    void pass(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || gen != _bakeGen) {
          if (gen == _bakeGen) {
            _bakePending = false;
          }
          return;
        }
        if (remaining > 1) {
          pass(remaining - 1);
          return;
        }
        unawaited(_bake(gen));
      });
    }

    pass(settlePasses.clamp(1, 4));
  }

  Future<void> _bake(int gen) async {
    try {
      if (!mounted || gen != _bakeGen) {
        return;
      }
      final scope = CyberBlurBackdropScope.maybeOf(context);
      final boundary = scope?.renderBoundary;
      if (scope == null || boundary == null || !boundary.hasSize) {
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale =
          (dpr / SettingsBlurHost.captureScaleFactor).clamp(0.25, dpr);
      final sigma = widget.blurSigma * scale;
      ui.Image? shared;
      try {
        shared = await scope.acquireBlurredCapture(
          pixelRatio: scale,
          sigmaX: sigma,
          sigmaY: sigma,
        );
      } catch (e) {
        debugPrint('settings-blur-host: bake capture failed: $e');
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      if (!mounted || gen != _bakeGen) {
        return;
      }
      if (shared == null || shared.width < 1 || shared.height < 1) {
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      final logical = MediaQuery.sizeOf(context);
      final minW = (logical.width * scale * 0.25).round();
      final minH = (logical.height * scale * 0.25).round();
      if (shared.width < minW || shared.height < minH) {
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 2);
        }
        return;
      }
      late final ui.Image owned;
      try {
        owned = shared.clone();
      } catch (e) {
        debugPrint('settings-blur-host: clone failed: $e');
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      if (!mounted || gen != _bakeGen) {
        owned.dispose();
        return;
      }
      widget.controller.accept(owned, sigma: widget.blurSigma);
      _bakeRetries = 0;
    } catch (e) {
      debugPrint('settings-blur-host: bake aborted: $e');
    } finally {
      if (gen == _bakeGen) {
        _bakePending = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Route-local mask: blit shared baked [RawImage], or live σ until ready.
class SettingsSharedBlurMask extends StatelessWidget {
  const SettingsSharedBlurMask({super.key});

  @override
  Widget build(BuildContext context) {
    final plateWidget = SettingsSharedBlurPlate.maybeWidgetOf(context);
    final plate = plateWidget?.notifier;
    final baked = plate?.image;
    final sigma = plate?.blurSigma ?? kSettingsPageBlurSigma;
    if (baked != null) {
      return IgnorePointer(
        child: RawImage(
          image: baked,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    final livePlate = plateWidget?.backdropBuilder ??
        () => const ColoredBox(color: Color(0xFF101218));
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.clamp,
        ),
        child: livePlate(),
      ),
    );
  }
}

/// Page stack over the shared plate when a [SettingsBlurHost] is an ancestor.
///
/// Without a host (tests), mounts a local [SettingsBlurHost] for the subtree.
class SettingsBlurredPageShell extends StatelessWidget {
  const SettingsBlurredPageShell({
    super.key,
    required this.child,
    this.blurSigma = kSettingsPageBlurSigma,
    this.backdropBuilder,
    this.livePageBlur = false,
  });

  final Widget child;
  final double blurSigma;
  final Widget Function()? backdropBuilder;
  final bool livePageBlur;

  static const captureScaleFactor = SettingsBlurHost.captureScaleFactor;

  @override
  Widget build(BuildContext context) {
    final shared = SettingsSharedBlurPlate.maybeOf(context);
    if (shared != null && !livePageBlur) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: SettingsSharedBlurMask()),
          child,
        ],
      );
    }

    final buildPlate = backdropBuilder ??
        () => const ColoredBox(color: Color(0xFF101218));
    if (livePageBlur) {
      return CyberBlurBackdropScope(
        child: SettingsPageBackdropBlur(
          sigma: blurSigma,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CyberBlurBackdropTarget(child: buildPlate()),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: ui.TileMode.clamp,
                    ),
                    child: buildPlate(),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      );
    }

    return SettingsBlurHost(
      blurSigma: blurSigma,
      backdropBuilder: buildPlate,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: SettingsSharedBlurMask()),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
