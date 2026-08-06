import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/bundled_firmware/application/control_board_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Host helper (`make upgrade-control-board`) command watcher.
///
/// File format (one command per line):
/// - `upgrade /run/hmi/control-board-upgrade/LSW01H####S####.bin`
/// - `clean`
final class SyncFirmwareCommandWatcher {
  SyncFirmwareCommandWatcher({
    required this.services,
    required this.navigatorContext,
    this.path = defaultPath,
    this.pollInterval = const Duration(milliseconds: 400),
  });

  static const defaultPath = '${OsPaths.runHmi}/upgrade-control-board.cmd';

  final AppServices services;

  /// Retained for API compatibility; host path uses navigatorKey via coordinator.
  final BuildContext? Function() navigatorContext;

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
      case 'upgrade':
        if (parts.length < 2) return;
        await _sync(parts[1]);
        break;
      case 'clean':
        break;
      default:
        break;
    }
  }

  Future<void> _sync(String firmwarePath) async {
    try {
      if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
        return;
      }
      final file = File(firmwarePath);
      if (!await file.exists()) {
        return;
      }
      await ControlBoardUpgradeCoordinator.instance.startHostUpgrade(file);
    } catch (_) {
      // Keep watcher alive; host will retry if needed.
    }
  }
}
