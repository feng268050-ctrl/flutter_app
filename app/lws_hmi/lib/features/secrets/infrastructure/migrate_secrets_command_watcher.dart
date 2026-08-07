import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/secrets.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Host `make migrate-secrets` writes `/run/hmi/migrate-secrets.cmd`.
///
/// Commands (one per write):
/// - `migrate` — Wi‑Fi vault + cloud Ed25519 (default)
/// - `migrate wifi` — vault only
/// - `migrate cloud` — Vendor Storage cloud key only
///
/// Unseals software (`LWSS`) blobs and re-seals with OP-TEE (`LWS1`). Skips
/// entries already on OP-TEE. Requires `secrets-seal probe` OK and a product SN
/// for the cloud path.
final class MigrateSecretsCommandWatcher {
  MigrateSecretsCommandWatcher({
    required this.services,
    this.path = defaultPath,
    this.pollInterval = const Duration(milliseconds: 400),
  });

  static const defaultPath = '${OsPaths.runHmi}/migrate-secrets.cmd';

  final AppServices services;
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
    if (op != 'migrate') {
      debugPrint('MigrateSecretsCommandWatcher: ignore "$line"');
      return;
    }
    var wifi = true;
    var cloud = true;
    if (parts.length >= 2) {
      final scope = parts[1].toLowerCase();
      switch (scope) {
        case 'wifi':
          cloud = false;
        case 'cloud':
          wifi = false;
        case 'all':
          break;
        default:
          debugPrint(
            'MigrateSecretsCommandWatcher: unknown scope "$scope" '
            '(use wifi|cloud|all)',
          );
          return;
      }
    }
    await _run(wifi: wifi, cloud: cloud);
  }

  Future<void> _run({required bool wifi, required bool cloud}) async {
    debugPrint(
      'MigrateSecretsCommandWatcher: start wifi=$wifi cloud=$cloud',
    );
    try {
      await SecretsBackendMigrator.ensureOpteeProbe();
    } catch (e) {
      debugPrint('MigrateSecretsCommandWatcher: OP-TEE probe failed: $e');
      return;
    }

    final source = SoftwareFallbackKekProvider();
    final target = OpteeKekProvider();
    final migrator = SecretsBackendMigrator(
      source: source,
      target: target,
    );

    String? sn;
    if (cloud) {
      try {
        final info = await services.ensureProductInfo();
        sn = info.sn.trim();
      } catch (e) {
        debugPrint('MigrateSecretsCommandWatcher: product SN read failed: $e');
      }
      if (sn == null || sn.isEmpty) {
        debugPrint(
          'MigrateSecretsCommandWatcher: empty product SN — cloud skipped',
        );
      }
    }

    try {
      final report = await migrator.migrate(
        wifi: wifi,
        cloud: cloud && sn != null && sn.isNotEmpty,
        productSn: sn,
      );
      debugPrint('MigrateSecretsCommandWatcher: $report');
      if (!report.ok) {
        debugPrint(
          'MigrateSecretsCommandWatcher: completed with failures '
          'wifiErrors=${report.wifiErrors} cloudError=${report.cloudError}',
        );
      }
    } catch (e) {
      debugPrint('MigrateSecretsCommandWatcher: migrate failed: $e');
    }
  }
}
