import 'dart:async';
import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_coordinator.dart';
import 'package:lws_hmi/features/upgrade_safety/upgrade_safety.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Host helper (`make upgrade-camera`) command watcher.
///
/// File format (one command per line):
/// - `download http://host:port/<zip>`
/// - `upgrade /run/hmi/camera-upgrade/<zip>` (legacy)
/// - `clean`
final class UpgradeCameraCommandWatcher {
  UpgradeCameraCommandWatcher({
    required this.services,
    required this.navigatorContext,
    this.path = defaultPath,
    this.pollInterval = const Duration(milliseconds: 400),
    SignedBlobFetch? signedFetch,
  }) : _signedFetch = signedFetch ?? SignedBlobFetch();

  static const defaultPath = '${OsPaths.runHmi}/upgrade-camera.cmd';

  final AppServices services;

  /// Retained for API compatibility; host path uses navigatorKey via coordinator.
  final BuildContext? Function() navigatorContext;

  final String path;
  final Duration pollInterval;
  final SignedBlobFetch _signedFetch;

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
        // ZIP basenames may contain spaces (URL-encoded); join remainder.
        await _downloadAndUpgrade(parts.sublist(1).join(' '));
        break;
      case 'upgrade':
        if (parts.length < 2) return;
        await _sync(parts.sublist(1).join(' '));
        break;
      case 'clean':
        break;
      default:
        break;
    }
  }

  Future<void> _downloadAndUpgrade(String packageUrl) async {
    try {
      if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
        return;
      }
      final uri = Uri.tryParse(packageUrl);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        return;
      }
      var fileName = uri.pathSegments.isEmpty
          ? ''
          : Uri.decodeComponent(uri.pathSegments.last);
      if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.zip')) {
        return;
      }
      await UpgradeSafety.stopWork(services, reason: 'camera-host');
      final verified = await _signedFetch.downloadAndVerify(
        packageUrl: packageUrl,
        stagingDir: kCameraStagingDir,
        fileName: fileName,
      );
      await CameraProgramUpgradeCoordinator.instance.startHostUpgrade(verified);
    } catch (_) {
      // Keep watcher alive; host will retry if needed.
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
      await CameraProgramUpgradeCoordinator.instance.startHostUpgrade(file);
    } catch (_) {
      // Keep watcher alive; host will retry if needed.
    }
  }
}
