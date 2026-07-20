import 'dart:async';
import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// App click backend: dedicated short-clip player (does not use media session).
///
/// One-shot mpg123/aplay playback of `assets/audio/click.mp3`. Volume remains
/// Settings / `cyber_hal` mixer — not media session volume.
class AppMediaClickSound implements CyberClickSound {
  AppMediaClickSound({
    String? cacheDir,
  }) : cacheDir = cacheDir ?? '${OsPaths.varHmi}/audio/clicks';

  final String cacheDir;

  static const assetKey = 'assets/audio/click.mp3';
  static const debounceMs = 150;

  String? _extractedPath;
  int _lastPlayUptimeMs = 0;
  String? _playerBinary;
  bool _playerResolved = false;

  @override
  Future<void> playClick() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayUptimeMs < debounceMs) {
      return;
    }
    _lastPlayUptimeMs = now;
    try {
      final path = await _ensureExtracted();
      final player = await _resolvePlayerBinary();
      if (player == null) {
        debugPrint('click-sfx: no mpg123/aplay on PATH');
        return;
      }
      final args = player.endsWith('mpg123') || player == 'mpg123'
          ? <String>['-q', path]
          : <String>[path];
      // Fire-and-forget; do not await process exit (must not block UI).
      unawaited(
        Process.start(player, args).then((p) => p.exitCode).catchError((_) => -1),
      );
    } catch (e) {
      debugPrint('click-sfx: play failed: $e');
    }
  }

  Future<String> _ensureExtracted() async {
    final cached = _extractedPath;
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }
    final name = assetKey.split('/').last;
    final dir = Directory(cacheDir);
    await dir.create(recursive: true);
    final out = File('${dir.path}/$name');
    final data = await rootBundle.load(assetKey);
    await out.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    _extractedPath = out.path;
    return out.path;
  }

  Future<String?> _resolvePlayerBinary() async {
    if (_playerResolved) {
      return _playerBinary;
    }
    _playerResolved = true;
    for (final name in <String>['mpg123', 'aplay']) {
      try {
        final r = await Process.run('which', <String>[name]);
        if (r.exitCode == 0) {
          final path = (r.stdout as String).trim();
          if (path.isNotEmpty) {
            _playerBinary = path;
            return path;
          }
        }
      } catch (_) {}
    }
    _playerBinary = null;
    return null;
  }
}
