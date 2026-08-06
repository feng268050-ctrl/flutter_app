import 'dart:async';
import 'dart:io';

import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/bundled_firmware/application/control_board_upgrade_checker.dart';
import 'package:lws_hmi/features/bundled_firmware/application/controller_upgrade_handler.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/firmware_upgrade_constants.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/bundled_firmware_assets.dart';

/// Bundled or host-pushed control-board firmware candidate.
final class ControlBoardFirmwareOffer {
  const ControlBoardFirmwareOffer({
    required this.fileName,
    required this.deviceSw,
    required this.bundledSw,
    this.assetKey,
    this.hostFile,
  });

  final String fileName;
  final int deviceSw;
  final int bundledSw;

  /// Flutter asset key when upgrading from ship tree.
  final String? assetKey;

  /// Absolute path when upgrading from host `make upgrade-control-board`.
  final File? hostFile;

  bool get isHostPush => hostFile != null;
}

/// Progress snapshot for the dedicated control-board upgrade page.
final class ControlBoardUpgradeProgress {
  const ControlBoardUpgradeProgress({
    this.percent = 0,
    this.isRunning = false,
    this.isTerminalOk = false,
    this.isTerminalFail = false,
    this.errorMessage,
  });

  final int percent;
  final bool isRunning;
  final bool isTerminalOk;
  final bool isTerminalFail;
  final String? errorMessage;

  static const idle = ControlBoardUpgradeProgress();
}

/// Orchestrates control-board Modbus flash for Settings / Home / host make.
final class ControlBoardUpgradeCoordinator {
  ControlBoardUpgradeCoordinator._();

  static final ControlBoardUpgradeCoordinator instance =
      ControlBoardUpgradeCoordinator._();

  GlobalKey<NavigatorState>? _navKey;
  AppServices? _services;

  final _progressController =
      StreamController<ControlBoardUpgradeProgress>.broadcast();
  ControlBoardUpgradeProgress _lastProgress = ControlBoardUpgradeProgress.idle;
  Future<void>? _runFuture;
  File? _pendingHostFile;

  Stream<ControlBoardUpgradeProgress> get progress =>
      _progressController.stream;
  ControlBoardUpgradeProgress get lastProgress => _lastProgress;
  bool get isSessionActive => _runFuture != null;
  File? get pendingHostFile => _pendingHostFile;

  void configure({
    required GlobalKey<NavigatorState> navigatorKey,
    required AppServices services,
  }) {
    _navKey = navigatorKey;
    _services = services;
  }

  /// Drop terminal / stale UI progress so a later page open starts clean.
  ///
  /// No-op while a Modbus transfer session is active.
  void clearProgress() {
    if (_runFuture != null) {
      return;
    }
    if (_lastProgress.isRunning ||
        _lastProgress.isTerminalOk ||
        _lastProgress.isTerminalFail ||
        _lastProgress.percent != 0) {
      _emit(ControlBoardUpgradeProgress.idle);
    }
  }

  void _emit(ControlBoardUpgradeProgress p) {
    _lastProgress = p;
    if (!_progressController.isClosed) {
      _progressController.add(p);
    }
  }

  /// Clears nav stack and opens progress-only upgrade page (host path).
  Future<void> navigateToUpgradePage() async {
    final nav = _navKey?.currentState;
    if (nav == null) {
      return;
    }
    nav.pushNamedAndRemoveUntil(
      AppRoutes.controlBoardUpgrade,
      (route) => false,
    );
  }

  Future<ControlBoardFirmwareOffer?> evaluateOffer({
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    final services = _services;
    if (services == null || !services.modbusLiveAllowed) {
      return null;
    }
    final deviceHw = await _readU16(FirmwareUpgradeConstants.deviceHw);
    final deviceSw = await _readU16(FirmwareUpgradeConstants.deviceSw);
    if (deviceHw == null || deviceSw == null) {
      return null;
    }

    final checker = ControlBoardUpgradeChecker(
      deviceHw: deviceHw,
      deviceSw: deviceSw,
    );
    final result = await checker.check(
      currentVersion: '$deviceSw',
      policy: policy,
    );
    if (result is! UpgradeCheckAvailable) {
      return null;
    }
    final fileName = result.offer.payload;
    if (fileName is! String) {
      return null;
    }
    final bundledSw = BundledFirmwareVersionGate.softwareVersion(fileName);
    if (bundledSw == null) {
      return null;
    }
    return ControlBoardFirmwareOffer(
      assetKey: '${BundledFirmwareAssets.assetPrefix}$fileName',
      fileName: fileName,
      deviceSw: deviceSw,
      bundledSw: bundledSw,
    );
  }

  /// Host `make upgrade-control-board`: stash file, open page, skip version gate.
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

  /// Consume pending host file once (page progress-only entry).
  File? takePendingHostFile() {
    final f = _pendingHostFile;
    _pendingHostFile = null;
    return f;
  }

  Future<void> runOfferUpgrade(
    ControlBoardFirmwareOffer offer, {
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    final services = _services;
    if (services == null) {
      return;
    }
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      throw StateError('upgrade_busy');
    }

    late final Uint8List bytes;
    if (offer.hostFile != null) {
      bytes = await offer.hostFile!.readAsBytes();
    } else if (offer.assetKey != null) {
      final data = await BundledFirmwareAssets.loadBytes(offer.assetKey!);
      if (data == null) {
        throw StateError('asset_missing');
      }
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } else {
      throw StateError('no_firmware_source');
    }

    await _beginRun(() async {
      FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
      try {
        _emit(
          const ControlBoardUpgradeProgress(isRunning: true, percent: 0),
        );
        final handler = ControllerUpgradeHandler(services.modbus);
        final result = await handler.upgrade(
          fileName: offer.fileName,
          bytes: bytes,
          onProgress: (p) {
            _emit(
              ControlBoardUpgradeProgress(
                isRunning: true,
                percent: p.clamp(0, 100),
              ),
            );
          },
          skipSameVersionCheck: !policy.checkVersion,
        );

        if (result.outcome == ControllerUpgradeOutcome.skippedSameVersion) {
          _emit(ControlBoardUpgradeProgress.idle);
          return;
        }
        if (result.isSuccess) {
          try {
            await services.modbus.readAttribute(
              FirmwareUpgradeConstants.deviceSw,
            );
          } catch (_) {}
          _emit(
            const ControlBoardUpgradeProgress(
              percent: 100,
              isTerminalOk: true,
            ),
          );
        } else {
          _emit(
            ControlBoardUpgradeProgress(
              isTerminalFail: true,
              errorMessage: result.errorMessage,
            ),
          );
        }
      } finally {
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

  Future<int?> _readU16(String id) async {
    final services = _services;
    if (services == null) {
      return null;
    }
    final v = await services.modbus.readAttribute(id);
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return null;
  }
}
