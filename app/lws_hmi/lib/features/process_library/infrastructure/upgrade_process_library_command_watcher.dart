import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Host helpers for process-library without restarting HMI:
/// - `make upgrade-process-library` → [upgradePath]
/// - `make reset-process-library` → [resetPath]
///
/// Upgrade file format (one command per line):
/// - `upgrade /run/hmi/process-library-upgrade/<dir>`
/// - `clean`
///
/// Reset file format:
/// - `reset`
/// - `clean`
final class UpgradeProcessLibraryCommandWatcher {
  UpgradeProcessLibraryCommandWatcher({
    required this.processLibrary,
    this.upgradePath = defaultUpgradePath,
    this.resetPath = defaultResetPath,
    this.pollInterval = const Duration(milliseconds: 400),
  });

  static const defaultUpgradePath =
      '${OsPaths.runHmi}/upgrade-process-library.cmd';
  static const defaultResetPath = '${OsPaths.runHmi}/reset-process-library.cmd';

  /// Backward-compatible alias for [defaultUpgradePath].
  static const defaultPath = defaultUpgradePath;

  final ProcessLibraryController processLibrary;
  final String upgradePath;
  final String resetPath;
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
    final upgradeLines = await _claimLines(upgradePath);
    final resetLines = await _claimLines(resetPath);
    if (upgradeLines.isEmpty && resetLines.isEmpty) {
      return;
    }

    _busy = true;
    try {
      for (final line in upgradeLines) {
        await _dispatchUpgradeLine(line);
      }
      for (final line in resetLines) {
        await _dispatchResetLine(line);
      }
    } finally {
      _busy = false;
    }
  }

  Future<List<String>> _claimLines(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const [];
    }
    final raw = await file.readAsString();
    try {
      await file.writeAsString('', flush: true);
    } catch (_) {
      return const [];
    }
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _dispatchUpgradeLine(String line) async {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return;
    }
    final op = parts.first.toLowerCase();
    switch (op) {
      case 'upgrade':
        if (parts.length < 2) return;
        await _upgrade(parts.sublist(1).join(' '));
        break;
      case 'clean':
        break;
      default:
        break;
    }
  }

  Future<void> _dispatchResetLine(String line) async {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return;
    }
    final op = parts.first.toLowerCase();
    switch (op) {
      case 'reset':
        await _reset();
        break;
      case 'clean':
        break;
      default:
        break;
    }
  }

  Future<void> _upgrade(String packagePath) async {
    try {
      final dir = Directory(packagePath);
      if (!await dir.exists()) {
        debugPrint(
          'UpgradeProcessLibrary: package dir missing: $packagePath',
        );
        return;
      }
      final audit = await processLibrary.importPackageForced(dir);
      debugPrint(
        'UpgradeProcessLibrary: status=${audit.status.name} '
        'version=${audit.toVersion ?? '-'} '
        'reason=${audit.skippedReason ?? '-'} '
        'errors=${audit.errors.join('; ')}',
      );
      if (audit.status == ProcessLibraryImportStatus.imported) {
        debugPrint(
          'UpgradeProcessLibrary: imported ${audit.rowCount} rows '
          '(${audit.fromVersion ?? 'none'} → ${audit.toVersion})',
        );
      }
    } catch (error, stack) {
      debugPrint('UpgradeProcessLibrary: failed: $error\n$stack');
    }
  }

  Future<void> _reset() async {
    try {
      final result = await processLibrary.resetAndReimportBundled();
      debugPrint(
        'ResetProcessLibrary: status=${result.status.name} '
        'version=${result.meta?.libraryVersion ?? '-'}',
      );
    } catch (error, stack) {
      debugPrint('ResetProcessLibrary: failed: $error\n$stack');
    }
  }
}
