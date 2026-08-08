import 'dart:async';
import 'dart:io';

import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_applicator.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_checker.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';
import 'package:lws_hmi/features/camera_update/infrastructure/bundled_camera_firmware_assets.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';

/// Bundled or host-pushed camera firmware candidate.
final class CameraProgramFirmwareOffer {
  const CameraProgramFirmwareOffer({
    required this.fileName,
    required this.deviceVersionLabel,
    required this.bundledVersionLabel,
    required this.cameraHost,
    this.assetKey,
    this.hostFile,
  });

  final String fileName;
  final String deviceVersionLabel;
  final String bundledVersionLabel;
  final String cameraHost;

  /// Flutter asset key when upgrading from ship tree.
  final String? assetKey;

  /// Absolute path when upgrading from host `make upgrade-camera`.
  final File? hostFile;

  bool get isHostPush => hostFile != null;
}

/// Progress snapshot for the dedicated camera program upgrade page.
final class CameraProgramUpgradeProgress {
  const CameraProgramUpgradeProgress({
    this.phase = CameraProgramUpgradePhase.transfer,
    this.percent = 0,
    this.isRunning = false,
    this.isTerminalOk = false,
    this.isTerminalFail = false,
    this.errorMessage,
  });

  final CameraProgramUpgradePhase phase;
  final int percent;
  final bool isRunning;
  final bool isTerminalOk;
  final bool isTerminalFail;
  final String? errorMessage;

  static const idle = CameraProgramUpgradeProgress();
}

/// Orchestrates camera CGI flash for Settings / Home / host make.
final class CameraProgramUpgradeCoordinator {
  CameraProgramUpgradeCoordinator._();

  static final CameraProgramUpgradeCoordinator instance =
      CameraProgramUpgradeCoordinator._();

  GlobalKey<NavigatorState>? _navKey;
  AppServices? _services;
  CameraDeviceInfoCache? _deviceInfo;

  final _progressController =
      StreamController<CameraProgramUpgradeProgress>.broadcast();
  CameraProgramUpgradeProgress _lastProgress = CameraProgramUpgradeProgress.idle;
  Future<void>? _runFuture;
  File? _pendingHostFile;

  Stream<CameraProgramUpgradeProgress> get progress =>
      _progressController.stream;
  CameraProgramUpgradeProgress get lastProgress => _lastProgress;
  bool get isSessionActive => _runFuture != null;
  File? get pendingHostFile => _pendingHostFile;

  void configure({
    required GlobalKey<NavigatorState> navigatorKey,
    required AppServices services,
    required CameraDeviceInfoCache deviceInfoCache,
  }) {
    _navKey = navigatorKey;
    _services = services;
    _deviceInfo = deviceInfoCache;
  }

  /// Drop terminal / stale UI progress so a later page open starts clean.
  void clearProgress() {
    if (_runFuture != null) {
      return;
    }
    if (_lastProgress.isRunning ||
        _lastProgress.isTerminalOk ||
        _lastProgress.isTerminalFail ||
        _lastProgress.percent != 0) {
      _emit(CameraProgramUpgradeProgress.idle);
    }
  }

  void _emit(CameraProgramUpgradeProgress p) {
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
      AppRoutes.cameraProgramUpgrade,
      (route) => false,
    );
  }

  Future<String?> _resolveCameraHost() async {
    final services = _services;
    if (services == null) {
      return null;
    }
    try {
      final product = await services.ensureProductInfo();
      final host = effectiveCameraHost(product).trim();
      return host.isEmpty ? null : host;
    } catch (_) {
      return null;
    }
  }

  Future<CameraProgramFirmwareOffer?> evaluateOffer({
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    final deviceInfo = _deviceInfo;
    if (deviceInfo == null) {
      return null;
    }
    final host = await _resolveCameraHost();
    if (host == null) {
      return null;
    }

    deviceInfo.invalidate();
    final raw = await deviceInfo.fetchRawAppVersion(host);
    final display = raw == null
        ? null
        : parseCameraAppVersionDisplay(raw);

    final checker = CameraProgramUpgradeChecker(
      deviceAppVersionRaw: raw,
    );
    final result = await checker.check(
      currentVersion: display ?? '',
      policy: policy,
    );
    if (result is! UpgradeCheckAvailable) {
      return null;
    }
    final fileName = result.offer.payload;
    if (fileName is! String) {
      return null;
    }
    final bundled =
        BundledCameraFirmwareVersionGate.parseFileName(fileName);
    if (bundled == null) {
      return null;
    }
    return CameraProgramFirmwareOffer(
      assetKey: '${BundledCameraFirmwareAssets.assetPrefix}$fileName',
      fileName: fileName,
      deviceVersionLabel: display ?? raw ?? '—',
      bundledVersionLabel: bundled.label,
      cameraHost: host,
    );
  }

  /// Host `make upgrade-camera`: stash file, open page, skip version gate.
  Future<void> startHostUpgrade(File firmwareFile) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      return;
    }
    if (!await firmwareFile.exists()) {
      return;
    }
    _pendingHostFile = firmwareFile;
    await navigateToUpgradePage();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
  }

  File? takePendingHostFile() {
    final f = _pendingHostFile;
    _pendingHostFile = null;
    return f;
  }

  Future<void> runOfferUpgrade(
    CameraProgramFirmwareOffer offer, {
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      throw StateError('upgrade_busy');
    }

    late final Uint8List bytes;
    if (offer.hostFile != null) {
      bytes = await offer.hostFile!.readAsBytes();
    } else if (offer.assetKey != null) {
      final data = await BundledCameraFirmwareAssets.loadBytes(offer.assetKey!);
      if (data == null) {
        throw StateError('asset_missing');
      }
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } else {
      throw StateError('no_firmware_source');
    }

    final deviceInfo = _deviceInfo;
    await _beginRun(() async {
      FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
      final applicator = CameraProgramUpgradeApplicator(
        deviceInfoCache: deviceInfo,
      );
      try {
        _emit(
          const CameraProgramUpgradeProgress(
            isRunning: true,
            phase: CameraProgramUpgradePhase.transfer,
            percent: 0,
          ),
        );
        final result = await applicator.upgrade(
          cameraHost: offer.cameraHost,
          fileName: offer.fileName,
          bytes: bytes,
          onProgress: (phase, percent) {
            _emit(
              CameraProgramUpgradeProgress(
                isRunning: true,
                phase: phase,
                percent: percent ?? 0,
              ),
            );
          },
        );

        if (result.isSuccess) {
          try {
            deviceInfo?.invalidate();
            await deviceInfo?.fetch(offer.cameraHost);
          } catch (_) {}
          _emit(
            const CameraProgramUpgradeProgress(
              percent: 100,
              phase: CameraProgramUpgradePhase.waitOnline,
              isTerminalOk: true,
            ),
          );
        } else {
          _emit(
            CameraProgramUpgradeProgress(
              isTerminalFail: true,
              phase: switch (result.outcome) {
                CameraProgramUpgradeOutcome.transferFailed =>
                  CameraProgramUpgradePhase.transfer,
                CameraProgramUpgradeOutcome.rebootFailed =>
                  CameraProgramUpgradePhase.reboot,
                CameraProgramUpgradeOutcome.waitTimeout =>
                  CameraProgramUpgradePhase.waitOnline,
                CameraProgramUpgradeOutcome.success =>
                  CameraProgramUpgradePhase.waitOnline,
              },
              errorMessage: result.errorMessage,
            ),
          );
        }
      } finally {
        applicator.dispose();
        FirmwareUpgradeCoordinator.markBundledUpgradeEnded();
      }
    });
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
}
