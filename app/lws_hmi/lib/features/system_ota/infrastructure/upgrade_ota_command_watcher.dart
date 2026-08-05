import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Host helper (`make upgrade`) command watcher for whole-device OTA.
///
/// File: `/run/hmi/upgrade-ota.cmd` (one command per line):
/// - `download <package_url> [oem_only=0|1]`
/// - `cancel`
final class UpgradeOtaCommandWatcher {
  UpgradeOtaCommandWatcher({
    SystemOtaCoordinator? coordinator,
    this.path = defaultPath,
    this.pollInterval = const Duration(milliseconds: 400),
  }) : coordinator = coordinator ?? SystemOtaCoordinator.instance;

  static const defaultPath = '${OsPaths.runHmi}/upgrade-ota.cmd';

  final SystemOtaCoordinator coordinator;
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
    switch (op) {
      case 'download':
        if (parts.length < 2) {
          return;
        }
        final packageUrl = parts[1];
        if (packageUrl.isEmpty ||
            !(packageUrl.startsWith('http://') ||
                packageUrl.startsWith('https://'))) {
          debugPrint(
            'UpgradeOtaCommandWatcher: ignoring invalid package_url: $packageUrl',
          );
          return;
        }
        final oemOnly = _parseOemOnly(parts.skip(2));
        try {
          await coordinator.startHostDownload(
            packageUrl: packageUrl,
            oemOnly: oemOnly,
          );
        } catch (e) {
          debugPrint('UpgradeOtaCommandWatcher: download failed: $e');
        }
        break;
      case 'cancel':
        coordinator.cancelIfAllowed();
        break;
      default:
        break;
    }
  }

  static bool _parseOemOnly(Iterable<String> tail) {
    for (final token in tail) {
      final lower = token.toLowerCase();
      if (lower == 'oem_only=1' || lower == '1') {
        return true;
      }
      if (lower == 'oem_only=0' || lower == '0') {
        return false;
      }
    }
    return false;
  }
}
