import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/bundled_firmware/application/controller_upgrade_handler.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/firmware_upgrade_constants.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/bundled_firmware_assets.dart';
import 'package:lws_hmi/features/bundled_firmware/presentation/bundled_firmware_dialogs.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';

/// Home-only: detect App-bundled control-board firmware and prompt before Modbus flash.
abstract final class BundledFirmwareBootstrap {
  static bool _sessionActive = false;

  /// Evaluate + optional confirm/upgrade. Safe to call repeatedly from Home.
  ///
  /// Enqueues on [GlobalPromptQueue] so confirm/progress cannot stack over
  /// other prompts.
  static Future<void> checkAndPromptIfNeeded(
    BuildContext context,
    AppServices services,
  ) async {
    if (!context.mounted) {
      return;
    }
    if (_sessionActive || FirmwareUpgradeCoordinator.isBusy) {
      return;
    }
    if (!services.modbusLiveAllowed) {
      return;
    }

    final queue = GlobalPromptScope.maybeOf(context);
    if (queue == null) {
      return;
    }

    final offer = await _evaluateOffer(services);
    if (offer == null || !context.mounted) {
      return;
    }

    await queue.enqueue(
      id: GlobalPromptIds.bundledFirmware,
      present: (host) async {
        if (_sessionActive || FirmwareUpgradeCoordinator.isBusy) {
          return;
        }
        final ctx = host.context;
        if (!ctx.mounted) {
          return;
        }
        final confirmed = await BundledFirmwareDialogs.showConfirm(
          context: ctx,
          currentVersion: '${offer.deviceSw}',
          newVersion: '${offer.bundledSw}',
        );
        if (!confirmed || !ctx.mounted) {
          return;
        }
        await _runUpgrade(
          context: ctx,
          services: services,
          offer: offer,
        );
      },
    );
  }

  /// Dev/ops helper: start bundled control-board firmware upgrade from a
  /// host-pushed `.bin` file (no confirm, no version gate).
  static Future<void> startSyncFirmwareUpgrade({
    required BuildContext context,
    required AppServices services,
    required File firmwareFile,
  }) async {
    if (!context.mounted) {
      return;
    }
    if (!services.modbusLiveAllowed) {
      return;
    }
    if (_sessionActive || FirmwareUpgradeCoordinator.isBusy) {
      return;
    }
    if (!await firmwareFile.exists()) {
      return;
    }

    final fileName = firmwareFile.path.split('/').last;
    Uint8List bytes;
    try {
      bytes = await firmwareFile.readAsBytes();
    } catch (_) {
      if (context.mounted) {
        await BundledFirmwareDialogs.showFailed(context);
      }
      return;
    }

    _sessionActive = true;
    FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
    final percent = ValueNotifier<int>(0);
    Future<void> Function() closeProgress = () async {};
    bool progressClosed = false;

    try {
      if (!context.mounted) {
        return;
      }
      closeProgress = BundledFirmwareDialogs.showProgress(
        context: context,
        percent: percent,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final handler = ControllerUpgradeHandler(services.modbus);
      final result = await handler.upgrade(
        fileName: fileName,
        bytes: bytes,
        onProgress: (p) => percent.value = p,
        skipSameVersionCheck: true,
      );

      await closeProgress();
      progressClosed = true;

      if (!context.mounted) {
        return;
      }

      if (result.isSuccess) {
        // Refresh live control SW for Device Information.
        await services.modbus.readAttribute(FirmwareUpgradeConstants.deviceSw);
        if (!context.mounted) {
          return;
        }
        await BundledFirmwareDialogs.showSuccess(context);
      } else {
        if (!context.mounted) {
          return;
        }
        await BundledFirmwareDialogs.showFailed(context);
      }
    } finally {
      percent.dispose();
      if (!progressClosed) {
        try {
          await closeProgress();
        } catch (_) {}
      }
      FirmwareUpgradeCoordinator.markBundledUpgradeEnded();
      _sessionActive = false;
    }
  }

  static Future<_HomeOffer?> _evaluateOffer(AppServices services) async {
    final deviceHw = await _readU16(
      services,
      FirmwareUpgradeConstants.deviceHw,
    );
    final deviceSw = await _readU16(
      services,
      FirmwareUpgradeConstants.deviceSw,
    );
    if (deviceHw == null || deviceSw == null) {
      return null;
    }

    final assetKey = await BundledFirmwareAssets.discoverAssetKey(
      deviceHw: deviceHw,
    );
    if (assetKey == null) {
      return null;
    }
    final fileName = assetKey.split('/').last;
    if (!BundledFirmwareVersionGate.isUpgradeCandidate(
      bundledFileName: fileName,
      deviceHw: deviceHw,
      deviceSw: deviceSw,
    )) {
      return null;
    }
    final bundledSw = BundledFirmwareVersionGate.softwareVersion(fileName)!;
    return _HomeOffer(
      assetKey: assetKey,
      fileName: fileName,
      deviceSw: deviceSw,
      bundledSw: bundledSw,
    );
  }

  static Future<void> _runUpgrade({
    required BuildContext context,
    required AppServices services,
    required _HomeOffer offer,
  }) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      debugPrint('BundledFirmwareBootstrap: coordinator busy');
      return;
    }

    final data = await BundledFirmwareAssets.loadBytes(offer.assetKey);
    if (data == null) {
      if (context.mounted) {
        await BundledFirmwareDialogs.showFailed(context);
      }
      return;
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    _sessionActive = true;
    FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
    final percent = ValueNotifier<int>(0);
    Future<void> Function()? closeProgress;

    try {
      if (!context.mounted) {
        return;
      }
      final close = BundledFirmwareDialogs.showProgress(
        context: context,
        percent: percent,
      );
      closeProgress = close;
      // Let the progress dialog paint before Modbus work.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final handler = ControllerUpgradeHandler(services.modbus);
      final result = await handler.upgrade(
        fileName: offer.fileName,
        bytes: Uint8List.fromList(bytes),
        onProgress: (p) {
          percent.value = p;
        },
      );

      await close();
      closeProgress = null;

      if (!context.mounted) {
        return;
      }
      if (result.outcome == ControllerUpgradeOutcome.skippedSameVersion) {
        return;
      }
      if (result.isSuccess) {
        // Refresh live control SW for Device Information.
        await services.modbus.readAttribute(
          FirmwareUpgradeConstants.deviceSw,
        );
        if (!context.mounted) {
          return;
        }
        await BundledFirmwareDialogs.showSuccess(context);
      } else {
        debugPrint(
          'BundledFirmwareBootstrap: upgrade failed ${result.errorMessage}',
        );
        if (!context.mounted) {
          return;
        }
        await BundledFirmwareDialogs.showFailed(context);
      }
    } finally {
      percent.dispose();
      final pendingClose = closeProgress;
      if (pendingClose != null) {
        try {
          await pendingClose();
        } catch (_) {}
      }
      FirmwareUpgradeCoordinator.markBundledUpgradeEnded();
      _sessionActive = false;
    }
  }

  static Future<int?> _readU16(AppServices services, String id) async {
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

final class _HomeOffer {
  const _HomeOffer({
    required this.assetKey,
    required this.fileName,
    required this.deviceSw,
    required this.bundledSw,
  });

  final String assetKey;
  final String fileName;
  final int deviceSw;
  final int bundledSw;
}
