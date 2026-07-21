import 'dart:async';
import 'dart:io';

import 'package:lws_hmi/platform/os_paths.dart';

/// Host `make alarm` / `make alarm-clean` drop commands here (USB-SSH / SSH).
///
/// File format (one command per write; host truncates after write):
/// - `trigger <CODE>` — arm demo warn (catalog code required)
/// - `clean` — clear episode restrictions; visible popup stays
final class DemoAlarmCommandWatcher {
  DemoAlarmCommandWatcher({
    required this.onTrigger,
    required this.onClean,
    this.path = defaultPath,
    this.pollInterval = const Duration(milliseconds: 400),
  });

  static const defaultPath = '${OsPaths.runHmi}/demo-alarm.cmd';

  final Future<void> Function(String code) onTrigger;
  final Future<void> Function() onClean;
  final String path;
  final Duration pollInterval;

  Timer? _timer;
  bool _busy = false;

  void start() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_tick()));
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() => stop();

  Future<void> _tick() async {
    if (_busy) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final raw = await file.readAsString();
    // Claim the file before handling so a second write is not lost silently.
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
        await _dispatch(line);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _dispatch(String line) async {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return;
    }
    final op = parts.first.toLowerCase();
    switch (op) {
      case 'trigger':
        if (parts.length < 2) {
          return;
        }
        // Do not await dialog lifetime — clean must stay responsive.
        unawaited(onTrigger(parts[1]));
      case 'clean':
        await onClean();
      default:
        break;
    }
  }
}
