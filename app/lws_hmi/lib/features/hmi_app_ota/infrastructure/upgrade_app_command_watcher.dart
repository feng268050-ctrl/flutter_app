import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/hmi_app_ota/application/hmi_app_upgrade_coordinator.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Host helper (`make upgrade-app`) command watcher.
///
/// File format (one command per line):
/// - `download http://host:port/<tar.gz>`
/// - `clean`
///
/// Download/verify/install run on the HMI Upgrade page (like system OTA host
/// path) so the operator sees phase progress.
final class UpgradeAppCommandWatcher {
  UpgradeAppCommandWatcher({
    required this.services,
    required this.navigatorContext,
    this.path = defaultPath,
    this.pollInterval = const Duration(milliseconds: 400),
  });

  static const defaultPath = '${OsPaths.runHmi}/upgrade-app.cmd';

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
      case 'download':
        if (parts.length < 2) return;
        await _startHostDownload(parts.sublist(1).join(' '));
        break;
      case 'clean':
        break;
      default:
        break;
    }
  }

  Future<void> _startHostDownload(String packageUrl) async {
    try {
      final uri = Uri.tryParse(packageUrl);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        debugPrint(
          'UpgradeAppCommandWatcher: ignoring invalid package_url: $packageUrl',
        );
        return;
      }
      var fileName = uri.pathSegments.isEmpty
          ? ''
          : Uri.decodeComponent(uri.pathSegments.last);
      if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.tar.gz')) {
        debugPrint(
          'UpgradeAppCommandWatcher: ignoring non-tar.gz url: $packageUrl',
        );
        return;
      }
      await HmiAppUpgradeCoordinator.instance.startHostDownload(
        packageUrl: packageUrl,
        fileName: fileName,
      );
    } catch (e, st) {
      debugPrint('UpgradeAppCommandWatcher: start failed: $e\n$st');
    }
  }
}
