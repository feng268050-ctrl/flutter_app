import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shared ~30 Hz clock for Home decorative WebP plates.
///
/// Asset frames are 33 ms; driving both plates from one tick avoids two
/// out-of-phase [Image.asset] completers dirtying the tree near panel rate.
final class PacedHomeWebpController extends ChangeNotifier {
  PacedHomeWebpController({
    required List<PacedHomeWebpSpec> layers,
    this.frameInterval = const Duration(milliseconds: 33),
    this.decodeSize = 200,
    bool playMotion = true,
    Timer Function(Duration period, void Function(Timer timer))? createPeriodic,
  })  : _specs = List<PacedHomeWebpSpec>.unmodifiable(layers),
        _playMotion = playMotion,
        _createPeriodic = createPeriodic ?? Timer.periodic {
    _layers = List<PacedHomeWebpLayerState>.generate(
      _specs.length,
      (_) => PacedHomeWebpLayerState(),
    );
  }

  /// Design / asset frame duration (~30.3 fps).
  final Duration frameInterval;

  /// Match historical [Image.asset] `cacheWidth`/`cacheHeight` for these plates.
  final int decodeSize;

  final List<PacedHomeWebpSpec> _specs;
  final Timer Function(Duration period, void Function(Timer timer))
      _createPeriodic;

  late final List<PacedHomeWebpLayerState> _layers;

  Timer? _timer;
  bool _playMotion;
  bool _paused = false;
  bool _started = false;
  bool _disposed = false;
  bool _tickInFlight = false;
  int _notifyCount = 0;

  bool get playMotion => _playMotion;

  bool get isPaused => _paused;

  bool get isRunning => _timer != null;

  /// Test/observability: how many [notifyListeners] calls since construct.
  @visibleForTesting
  int get notifyCount => _notifyCount;

  /// When set, [debugTick] / the periodic timer use this instead of the codec.
  @visibleForTesting
  Future<void> Function(PacedHomeWebpLayerState layer)? debugAdvanceLayer;

  int get layerCount => _layers.length;

  ui.Image? imageAt(int index) {
    if (index < 0 || index >= _layers.length) {
      return null;
    }
    return _layers[index].image;
  }

  bool failedAt(int index) {
    if (index < 0 || index >= _layers.length) {
      return true;
    }
    return _layers[index].failed;
  }

  String fallbackAt(int index) => _specs[index].fallback;

  String assetAt(int index) => _specs[index].asset;

  /// Start codecs and the shared tick (no-op when [playMotion] is false).
  Future<void> start() async {
    if (_disposed || _started) {
      return;
    }
    _started = true;
    if (!_playMotion) {
      return;
    }
    // Tests inject [debugAdvanceLayer] and do not need real asset codecs.
    if (debugAdvanceLayer == null) {
      await _loadAll();
    }
    if (_disposed || !_playMotion) {
      return;
    }
    _ensureTimer();
  }

  set playMotion(bool value) {
    if (_playMotion == value) {
      return;
    }
    _playMotion = value;
    if (!_playMotion) {
      _stopTimer();
      _clearImages();
      _notify();
      return;
    }
    if (_started && !_paused) {
      unawaited(_reloadAndRun());
    }
  }

  void pause() {
    if (_paused) {
      return;
    }
    _paused = true;
    _stopTimer();
  }

  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    if (!_started || !_playMotion || _disposed) {
      return;
    }
    _ensureTimer();
  }

  /// Advance one shared tick (tests / manual). Coalesces to one notify.
  @visibleForTesting
  Future<void> debugTick() => _onTick();

  Future<void> _reloadAndRun() async {
    await _loadAll();
    if (_disposed || !_playMotion || _paused) {
      return;
    }
    _ensureTimer();
  }

  Future<void> _loadAll() async {
    for (var i = 0; i < _specs.length; i++) {
      await _loadLayer(i);
      if (_disposed) {
        return;
      }
    }
    _notify();
  }

  Future<void> _loadLayer(int index) async {
    final layer = _layers[index];
    layer.failed = false;
    try {
      final data = await rootBundle.load(_specs[index].asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: decodeSize,
        targetHeight: decodeSize,
      );
      layer.codec?.dispose();
      layer.codec = codec;
      final frame = await codec.getNextFrame();
      layer.image?.dispose();
      layer.image = frame.image;
    } catch (e, st) {
      debugPrint('PacedHomeWebp: load ${_specs[index].asset} failed: $e\n$st');
      layer.failed = true;
      layer.codec?.dispose();
      layer.codec = null;
      layer.image?.dispose();
      layer.image = null;
    }
  }

  void _ensureTimer() {
    if (_timer != null || _disposed || !_playMotion || _paused) {
      return;
    }
    _timer = _createPeriodic(frameInterval, (_) {
      unawaited(_onTick());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _onTick() async {
    if (_disposed || !_playMotion || _paused || _tickInFlight) {
      return;
    }
    _tickInFlight = true;
    try {
      var any = false;
      for (final layer in _layers) {
        final debugAdvance = debugAdvanceLayer;
        if (debugAdvance != null) {
          await debugAdvance(layer);
          any = true;
          continue;
        }
        final codec = layer.codec;
        if (codec == null || layer.failed) {
          continue;
        }
        try {
          final frame = await codec.getNextFrame();
          layer.image?.dispose();
          layer.image = frame.image;
          any = true;
        } catch (e, st) {
          debugPrint('PacedHomeWebp: frame advance failed: $e\n$st');
          layer.failed = true;
          layer.codec?.dispose();
          layer.codec = null;
          layer.image?.dispose();
          layer.image = null;
          any = true;
        }
      }
      if (any && !_disposed) {
        _notify();
      }
    } finally {
      _tickInFlight = false;
    }
  }

  void _clearImages() {
    for (final layer in _layers) {
      layer.codec?.dispose();
      layer.codec = null;
      layer.image?.dispose();
      layer.image = null;
      layer.failed = false;
    }
  }

  void _notify() {
    _notifyCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    _clearImages();
    super.dispose();
  }
}

/// One decorative plate: animated asset + static fallback.
final class PacedHomeWebpSpec {
  const PacedHomeWebpSpec({
    required this.asset,
    required this.fallback,
  });

  final String asset;
  final String fallback;
}

final class PacedHomeWebpLayerState {
  ui.Codec? codec;
  ui.Image? image;
  bool failed = false;
}

/// Positioned plate that paints [PacedHomeWebpController] layer [layerIndex].
class PacedHomeWebpPlate extends StatelessWidget {
  const PacedHomeWebpPlate({
    super.key,
    required this.controller,
    required this.layerIndex,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final PacedHomeWebpController controller;
  final int layerIndex;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            // Balanced / no-motion: do not paint the plate. Fallback assets
            // (`home_*_img.webp`) are Quick/Engineer card frames already shown
            // via Home `_PositionedAsset` at the correct 375×280 slots. Drawing
            // them in this oversized plate puts the frame's inner edges beside
            // the clock as two vertical lines.
            if (!controller.playMotion) {
              return const SizedBox.shrink();
            }
            if (controller.failedAt(layerIndex)) {
              return Image.asset(
                controller.fallbackAt(layerIndex),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                cacheWidth: controller.decodeSize,
                cacheHeight: controller.decodeSize,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );
            }
            final image = controller.imageAt(layerIndex);
            if (image == null) {
              return const SizedBox.shrink();
            }
            return RawImage(
              image: image,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
            );
          },
        ),
      ),
    );
  }
}
