import 'dart:ui' show FramePhase, FrameTiming;

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/scheduler.dart';

/// Aggregates Flutter [FrameTiming] into ~1 Hz UI/raster FPS for [SysInfo].
///
/// Uses engine timestamps ([FrameTiming.timestampInMicroseconds]), not wall
/// clock at callback delivery — batches no longer collapse to one `DateTime`.
///
/// UI FPS: frames with non-zero [FrameTiming.buildDuration], keyed by
/// [FramePhase.buildFinish]. Raster FPS: non-zero raster duration, keyed by
/// [FramePhase.rasterFinish].
final class FlutterFrameTimingSampler implements FrameTimingSampler {
  FlutterFrameTimingSampler({
    this.window = const Duration(seconds: 1),
    SchedulerBinding? binding,
  }) : _binding = binding ?? SchedulerBinding.instance {
    _binding.addTimingsCallback(_onTimings);
  }

  final Duration window;
  final SchedulerBinding _binding;

  /// Monotonic engine timestamps (µs) for UI/build finish.
  final List<int> _uiTsUs = <int>[];

  /// Monotonic engine timestamps (µs) for raster finish.
  final List<int> _rasterTsUs = <int>[];

  double? _uiFps;
  double? _rasterFps;

  @override
  double? get uiFps => _uiFps;

  @override
  double? get rasterFps => _rasterFps;

  void dispose() {
    _binding.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      if (t.buildDuration > Duration.zero) {
        _uiTsUs.add(t.timestampInMicroseconds(FramePhase.buildFinish));
      }
      if (t.rasterDuration > Duration.zero) {
        _rasterTsUs.add(t.timestampInMicroseconds(FramePhase.rasterFinish));
      }
    }
    _uiTsUs.sort();
    _rasterTsUs.sort();

    final windowUs = window.inMicroseconds;
    if (windowUs <= 0) {
      return;
    }

    _prune(_uiTsUs, windowUs);
    _prune(_rasterTsUs, windowUs);
    _uiFps = fpsFromTimestamps(_uiTsUs, windowUs);
    _rasterFps = fpsFromTimestamps(_rasterTsUs, windowUs);
  }

  static void _prune(List<int> ts, int windowUs) {
    if (ts.isEmpty) {
      return;
    }
    final cutoff = ts.last - windowUs;
    ts.removeWhere((t) => t < cutoff);
  }

  /// FPS from sorted timestamps in a sliding window ending at the last sample.
  ///
  /// With ≥2 frames: `(n - 1) / (last - first)` in Hz (span-based).
  /// With 1 frame: treat as one frame over [windowUs] (lower bound).
  static double? fpsFromTimestamps(List<int> sortedTsUs, int windowUs) {
    if (sortedTsUs.isEmpty || windowUs <= 0) {
      return null;
    }
    if (sortedTsUs.length == 1) {
      return 1e6 / windowUs;
    }
    final spanUs = sortedTsUs.last - sortedTsUs.first;
    if (spanUs <= 0) {
      return null;
    }
    return (sortedTsUs.length - 1) * 1e6 / spanUs;
  }
}
