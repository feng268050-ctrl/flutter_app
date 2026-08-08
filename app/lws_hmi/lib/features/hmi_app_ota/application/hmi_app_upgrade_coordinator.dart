import 'dart:async';
import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/hmi_app_ota/application/hmi_app_upgrade_mapping.dart';
import 'package:lws_hmi/features/hmi_app_ota/infrastructure/hmi_app_tree_install.dart';
import 'package:lws_hmi/features/upgrade_safety/upgrade_safety.dart';

/// Cloud or host-pushed HMI app package candidate.
final class HmiAppUpgradeOffer {
  const HmiAppUpgradeOffer({
    required this.version,
    required this.fileName,
    this.packageUrl,
    this.hostFile,
  });

  /// Manifest / display version (may include leading `v`).
  final String version;
  final String fileName;
  final String? packageUrl;
  final File? hostFile;

  bool get isHostPush => hostFile != null || packageUrl != null;
}

enum HmiAppUpgradePhase { download, verify, extract, write, restart }

/// Progress snapshot for the HMI Upgrade page.
final class HmiAppUpgradeProgress {
  const HmiAppUpgradeProgress({
    this.phase = HmiAppUpgradePhase.download,
    this.percent = 0,
    this.isRunning = false,
    this.isTerminalOk = false,
    this.isTerminalFail = false,
    this.errorMessage,
  });

  final HmiAppUpgradePhase phase;
  final int percent;
  final bool isRunning;
  final bool isTerminalOk;
  final bool isTerminalFail;
  final String? errorMessage;

  static const idle = HmiAppUpgradeProgress();
}

typedef HmiAppManifestUrlResolver = String? Function();

/// Orchestrates signed HMI app tar.gz install + `hmi.service` restart.
final class HmiAppUpgradeCoordinator {
  HmiAppUpgradeCoordinator._();

  static final HmiAppUpgradeCoordinator instance = HmiAppUpgradeCoordinator._();

  static const stagingDir = '/var/lib/hmi/upgrade-app-staging';

  /// Transient unit outside [hmi.service] cgroup — required because
  /// `KillMode=control-group` would kill an in-cgroup `systemctl restart`.
  static const restartUnit = 'hmi-upgrade-app-restart.service';

  GlobalKey<NavigatorState>? _navKey;
  AppServices? _services;
  HmiAppManifestUrlResolver? _manifestUrlResolver;
  OtaHttpClient _http = HttpOtaClient();
  SignedBlobFetch _signedFetch = SignedBlobFetch();
  OtaExtract _extract = OtaExtract();
  HmiAppTreeInstall _treeInstall = HmiAppTreeInstall();

  final _progressController =
      StreamController<HmiAppUpgradeProgress>.broadcast();
  HmiAppUpgradeProgress _lastProgress = HmiAppUpgradeProgress.idle;
  Future<void>? _runFuture;

  Stream<HmiAppUpgradeProgress> get progress => _progressController.stream;
  HmiAppUpgradeProgress get lastProgress => _lastProgress;
  bool get isSessionActive => _runFuture != null;

  void configure({
    required GlobalKey<NavigatorState> navigatorKey,
    required AppServices services,
    required HmiAppManifestUrlResolver manifestUrlResolver,
    OtaHttpClient? httpClient,
    SignedBlobFetch? signedFetch,
    OtaExtract? extract,
    HmiAppTreeInstall? treeInstall,
  }) {
    _navKey = navigatorKey;
    _services = services;
    _manifestUrlResolver = manifestUrlResolver;
    if (httpClient != null) {
      _http = httpClient;
    }
    if (signedFetch != null) {
      _signedFetch = signedFetch;
    }
    if (extract != null) {
      _extract = extract;
    }
    if (treeInstall != null) {
      _treeInstall = treeInstall;
    }
  }

  void clearProgress() {
    if (_runFuture != null) {
      return;
    }
    if (_lastProgress.isRunning ||
        _lastProgress.isTerminalOk ||
        _lastProgress.isTerminalFail ||
        _lastProgress.percent != 0) {
      _emit(HmiAppUpgradeProgress.idle);
    }
  }

  void _emit(HmiAppUpgradeProgress p) {
    _lastProgress = p;
    if (!_progressController.isClosed) {
      _progressController.add(p);
    }
  }

  Future<void> navigateToUpgradePage() async {
    final nav = _navKey?.currentState;
    if (nav == null) {
      return;
    }
    nav.pushNamedAndRemoveUntil(
      AppRoutes.hmiUpgrade,
      (route) => false,
    );
  }

  /// Cloud check against `lws-hmi/app/release.json` vs [kHmiVersion].
  Future<CheckUpdateResult> checkForUpdate({String? manifestUrl}) async {
    final url = manifestUrl ?? _manifestUrlResolver?.call();
    if (url == null || url.trim().isEmpty) {
      throw StateError('manifest_unavailable');
    }
    if (!shouldRunVersionCheck(HmiAppUpgradeMapping.operatorPolicy)) {
      return const CheckUpdateResult(hasUpdate: false);
    }
    final json = await _http.getJson(url);
    final manifest = OtaManifest.fromJson(json);
    final local = OtaManifest.coreVersion(kHmiVersion) ?? kHmiVersion;
    final remote =
        OtaManifest.coreVersion(manifest.version) ?? manifest.version.trim();
    final hasUpdate =
        local.isNotEmpty && remote.isNotEmpty && isNewer(remote, local);
    return CheckUpdateResult(
      hasUpdate: hasUpdate,
      manifest: hasUpdate ? manifest : null,
    );
  }

  /// Host `make upgrade-app`: open progress page, then download → verify → apply.
  Future<void> startHostDownload({
    required String packageUrl,
    required String fileName,
  }) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      return;
    }
    if (isSessionActive) {
      return;
    }
    final services = _services;
    if (services != null) {
      await UpgradeSafety.stopWork(services, reason: 'hmi-app-host');
    }
    await navigateToUpgradePage();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    unawaited(
      runOfferUpgrade(
        HmiAppUpgradeOffer(
          version: '0.0.0-host',
          fileName: fileName,
          packageUrl: packageUrl,
        ),
        policy: HmiAppUpgradeMapping.hostForcePolicy,
      ),
    );
  }

  /// Operator Update Now (cloud) or host URL already navigating.
  Future<void> runOfferUpgrade(
    HmiAppUpgradeOffer offer, {
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      throw StateError('upgrade_busy');
    }

    await _beginRun(() async {
      FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
      try {
        final services = _services;
        if (services != null && policy == UpgradePolicy.operator) {
          await UpgradeSafety.stopWork(
            services,
            reason: 'hmi-app-upgrade',
          );
        }

        late final File package;
        if (offer.hostFile != null) {
          package = offer.hostFile!;
          _emit(
            const HmiAppUpgradeProgress(
              isRunning: true,
              phase: HmiAppUpgradePhase.verify,
              percent: 100,
            ),
          );
        } else if (offer.packageUrl != null) {
          _emit(
            const HmiAppUpgradeProgress(
              isRunning: true,
              phase: HmiAppUpgradePhase.download,
              percent: 0,
            ),
          );
          try {
            package = await _signedFetch.downloadAndVerify(
              packageUrl: offer.packageUrl!,
              stagingDir: kAppStagingDir,
              fileName: offer.fileName,
              onProgress: (received, total) {
                final pct = total == null || total <= 0
                    ? 0
                    : ((received * 100) / total).round().clamp(0, 100);
                _emit(
                  HmiAppUpgradeProgress(
                    isRunning: true,
                    phase: HmiAppUpgradePhase.download,
                    percent: pct,
                  ),
                );
              },
            );
            _emit(
              const HmiAppUpgradeProgress(
                isRunning: true,
                phase: HmiAppUpgradePhase.verify,
                percent: 100,
              ),
            );
            // Brief verify chrome before install (sig already checked in fetch).
            await Future<void>.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            _emit(
              HmiAppUpgradeProgress(
                isTerminalFail: true,
                phase: HmiAppUpgradePhase.download,
                errorMessage: '$e',
              ),
            );
            return;
          }
        } else {
          throw StateError('no_package_source');
        }

        await _applyAndAwaitRestart(package);
      } finally {
        // Process usually dies on hmi.service restart; clear mutex if still up.
        FirmwareUpgradeCoordinator.markBundledUpgradeEnded();
      }
    });
  }

  Future<void> _applyAndAwaitRestart(File verifiedTarGz) async {
    _emit(
      const HmiAppUpgradeProgress(
        isRunning: true,
        phase: HmiAppUpgradePhase.extract,
        percent: 0,
      ),
    );

    // Same as System OTA: feed compressed bytes into `tar -xz` with % progress.
    try {
      final stage = Directory(stagingDir);
      if (await stage.exists()) {
        await stage.delete(recursive: true);
      }
      await stage.create(recursive: true);
      await _extract.extractArchive(
        archivePath: verifiedTarGz.absolute.path,
        stagingDir: stagingDir,
        onProgress: (read, total) {
          final pct = total <= 0 ? 0 : (read * 100 ~/ total).clamp(0, 100);
          _emit(
            HmiAppUpgradeProgress(
              isRunning: true,
              phase: HmiAppUpgradePhase.extract,
              percent: pct,
            ),
          );
        },
      );
      _emit(
        const HmiAppUpgradeProgress(
          isRunning: true,
          phase: HmiAppUpgradePhase.extract,
          percent: 100,
        ),
      );
    } catch (e, st) {
      debugPrint('HmiAppUpgrade: extract failed: $e\n$st');
      _emit(
        HmiAppUpgradeProgress(
          isTerminalFail: true,
          phase: HmiAppUpgradePhase.extract,
          errorMessage: '$e',
        ),
      );
      return;
    }

    // Tree install: plain copies + live bin/lib rename (not DdWriter).
    _emit(
      const HmiAppUpgradeProgress(
        isRunning: true,
        phase: HmiAppUpgradePhase.write,
        percent: 0,
      ),
    );
    try {
      await _treeInstall.installFromStaging(
        stagingDir: stagingDir,
        onProgress: (written, total) {
          final pct = total <= 0 ? 0 : (written * 100 ~/ total).clamp(0, 100);
          _emit(
            HmiAppUpgradeProgress(
              isRunning: true,
              phase: HmiAppUpgradePhase.write,
              percent: pct,
            ),
          );
        },
      );
      _emit(
        const HmiAppUpgradeProgress(
          isRunning: true,
          phase: HmiAppUpgradePhase.write,
          percent: 100,
        ),
      );
    } catch (e, st) {
      debugPrint('HmiAppUpgrade: install failed: $e\n$st');
      _emit(
        HmiAppUpgradeProgress(
          isTerminalFail: true,
          phase: HmiAppUpgradePhase.write,
          errorMessage: '$e',
        ),
      );
      return;
    }

    _emit(
      const HmiAppUpgradeProgress(
        isRunning: true,
        phase: HmiAppUpgradePhase.restart,
        percent: 100,
      ),
    );
    // Let Restarting chrome paint before the unit cycles.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    try {
      await _restartHmiOutsideCgroup();
    } catch (e, st) {
      debugPrint('HmiAppUpgrade: restart launch failed: $e\n$st');
      _emit(
        HmiAppUpgradeProgress(
          isTerminalFail: true,
          phase: HmiAppUpgradePhase.restart,
          errorMessage: '$e',
        ),
      );
    }
    // Process is killed when hmi.service restarts; no further UI.
  }

  /// `systemd-run` + `systemctl restart hmi` outside the HMI cgroup.
  Future<void> _restartHmiOutsideCgroup() async {
    await Process.run('systemctl', ['reset-failed', restartUnit]);
    final result = await Process.run(
      'systemd-run',
      [
        '--unit=$restartUnit',
        '--collect',
        'systemctl',
        'restart',
        'hmi.service',
      ],
    );
    if (result.exitCode != 0) {
      final err = '${result.stderr}'.trim();
      throw StateError(
        'systemd-run restart failed (${result.exitCode})'
        '${err.isEmpty ? '' : ': $err'}',
      );
    }
  }

  Future<void> _beginRun(Future<void> Function() body) async {
    if (_runFuture != null) {
      throw StateError('session_active');
    }
    final future = body();
    _runFuture = future;
    try {
      await future;
    } finally {
      if (identical(_runFuture, future)) {
        _runFuture = null;
      }
    }
  }

  /// Test hook.
  @visibleForTesting
  void resetForTest() {
    _runFuture = null;
    _emit(HmiAppUpgradeProgress.idle);
    FirmwareUpgradeCoordinator.resetForTest();
  }
}
