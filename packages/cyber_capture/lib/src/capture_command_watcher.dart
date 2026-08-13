import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'capture_controller.dart';
import 'capture_paths.dart';

/// Host helper command watcher for `/run/hmi/capture.cmd`.
///
/// Lines (one command per line):
/// - `screenshot [rotate=N] [q=N]`
/// - `record-start [fps=N] [scale=N] [rotate=N] [audio=0|1]`
/// - `record-stop`
/// - `cleanup <path>`
final class CaptureCommandWatcher {
  CaptureCommandWatcher({
    CaptureController? controller,
    this.path = CapturePaths.commandFile,
    this.pollInterval = const Duration(milliseconds: 400),
  }) : controller = controller ?? CaptureController();

  final CaptureController controller;
  final String path;
  final Duration pollInterval;

  Timer? _timer;
  bool _busy = false;
  String? lastOutDir;

  void start() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_tick()));
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final raw = await file.readAsString();
    try {
      await file.writeAsString('', flush: true);
    } catch (_) {
      return;
    }

    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    if (lines.isEmpty) {
      return;
    }

    _busy = true;
    try {
      for (final line in lines) {
        await _dispatchLine(line);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _dispatchLine(String line) async {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return;
    }
    final op = parts.first.toLowerCase();
    final kv = _parseKv(parts.skip(1));
    switch (op) {
      case 'screenshot':
        final rotate = int.tryParse(kv['rotate'] ?? '') ?? 0;
        final q = int.tryParse(kv['q'] ?? '') ?? 80;
        lastOutDir = await controller.screenshot(rotateDeg: rotate, qFactor: q);
        debugPrint('cyber_capture: screenshot → $lastOutDir');
        break;
      case 'record-start':
        final fps = int.tryParse(kv['fps'] ?? '') ?? 30;
        final scale = int.tryParse(kv['scale'] ?? '') ?? 100;
        final rotate = int.tryParse(kv['rotate'] ?? '') ?? 0;
        final audio = (kv['audio'] ?? '0') == '1';
        lastOutDir = await controller.recordStart(
          fps: fps,
          scalePct: scale,
          rotateDeg: rotate,
          audio: audio,
        );
        debugPrint('cyber_capture: record-start → $lastOutDir');
        break;
      case 'record-stop':
        await controller.recordStop();
        debugPrint('cyber_capture: record-stop');
        break;
      case 'cleanup':
        if (parts.length < 2) {
          return;
        }
        await controller.cleanup(parts[1]);
        debugPrint('cyber_capture: cleanup ${parts[1]}');
        break;
      default:
        debugPrint('cyber_capture: unknown op=$op');
        break;
    }
  }

  static Map<String, String> _parseKv(Iterable<String> tokens) {
    final out = <String, String>{};
    for (final t in tokens) {
      final i = t.indexOf('=');
      if (i <= 0) {
        continue;
      }
      out[t.substring(0, i).toLowerCase()] = t.substring(i + 1);
    }
    return out;
  }
}
