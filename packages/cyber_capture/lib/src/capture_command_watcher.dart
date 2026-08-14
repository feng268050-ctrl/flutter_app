import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'capture_controller.dart';
import 'capture_paths.dart';

/// Host helper command watcher for `/run/hmi/capture.cmd`.
///
/// Lines (one command per line):
/// - `screenshot [rotate=N] [q=N]`
/// - `record-start [fps=N] [scale=N] [rotate=N] [audio=0|1] [adev=NAME]`
/// - `record-stop`
/// - `cleanup <path>`
final class CaptureCommandWatcher {
  CaptureCommandWatcher({
    CaptureController? controller,
    this.path = CapturePaths.commandFile,
    this.pollInterval = const Duration(milliseconds: 100),
  }) : controller = controller ?? CaptureController();

  final CaptureController controller;
  final String path;
  final Duration pollInterval;

  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<FileSystemEvent>? _watchSub;
  bool _busy = false;
  bool _started = false;
  String? lastOutDir;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _ensureDirs();
    if (!_started) {
      return;
    }
    _timer = Timer.periodic(pollInterval, (_) => _scheduleTick());
    _startWatch();
    // Warm GStreamer in the background so a slow gst_init does not block cmd I/O.
    unawaited(controller.warm());
    await _tick();
  }

  Future<void> _ensureDirs() async {
    try {
      await Directory(CapturePaths.captureRoot).create(recursive: true);
      await File(path).parent.create(recursive: true);
      if (!await File(path).exists()) {
        await File(path).writeAsString('', flush: true);
      }
    } catch (e) {
      debugPrint('cyber_capture: ensure dirs failed: $e');
    }
  }

  void _scheduleTick() {
    if (_busy) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 25), () {
      unawaited(_tick());
    });
  }

  void _startWatch() {
    try {
      final parent = File(path).parent;
      _watchSub = parent.watch(events: FileSystemEvent.all).listen((event) {
        if (event.path == path ||
            event.path.endsWith('capture.cmd') ||
            event.path.endsWith('capture.cmd.tmp')) {
          _scheduleTick();
        }
      });
    } catch (e) {
      debugPrint('cyber_capture: watch unavailable: $e');
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
    await _watchSub?.cancel();
    _watchSub = null;
    _started = false;
  }

  Future<void> _tick() async {
    if (_busy) {
      return;
    }
    // Claim before any await — concurrent timer + inotify ticks otherwise
    // race: one clears capture.cmd while another reads empty and drops ops.
    _busy = true;
    try {
      final file = File(path);
      if (!await file.exists()) {
        return;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }
      try {
        await file.writeAsString('', flush: true);
      } catch (_) {
        return;
      }

      final lines = raw
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
      if (lines.isEmpty) {
        return;
      }

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
        final adev = (kv['adev'] ?? 'default').trim();
        lastOutDir = await controller.recordStart(
          fps: fps,
          scalePct: scale,
          rotateDeg: rotate,
          audio: audio,
          audioDev: adev.isEmpty ? 'default' : adev,
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
