import 'dart:async';
import 'dart:io';

import 'package:lws_hmi/features/bundled_firmware/application/bundled_firmware_bootstrap.dart';
import 'package:lws_hmi/platform/os_paths.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:flutter/material.dart';

/// Host helper (`make upgrade-control-board`) command watcher.
///
/// Writes a command file on the device (tmpfs) and HMI executes a sync
/// firmware upgrade without confirm / without version gate.
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

  /// HMI services used to access Modbus.
  final AppServices services;

  /// When a command arrives, watcher uses the current context to show dialogs.
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
        final firmwarePath = parts[1];
        await _sync(firmwarePath);
        break;
      case 'clean':
        // No-op: file was already cleared by the claim step.
        break;
      default:
        break;
    }
  }

  Future<void> _sync(String firmwarePath) async {
    try {
      final ctx = navigatorContext();
      if (ctx == null || !ctx.mounted) {
        return;
      }
      final file = File(firmwarePath);
      if (!await file.exists()) {
        return;
      }
      await BundledFirmwareBootstrap.startSyncFirmwareUpgrade(
        // ignore: use_build_context_synchronously
        context: ctx,
        services: services,
        firmwareFile: file,
      );
      if (!ctx.mounted) {
        return;
      }
    } catch (_) {
      // Keep watcher alive; host will retry if needed.
    }
  }
}

