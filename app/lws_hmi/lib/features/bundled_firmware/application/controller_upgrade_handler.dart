import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/firmware_upgrade_constants.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/upgrade_packet_builder.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

enum ControllerUpgradeOutcome {
  success,
  failed,
  skippedSameVersion,
}

/// Result of a control-board Modbus firmware transfer.
final class ControllerUpgradeResult {
  const ControllerUpgradeResult(this.outcome, {this.errorMessage});

  final ControllerUpgradeOutcome outcome;
  final String? errorMessage;

  bool get isSuccess => outcome == ControllerUpgradeOutcome.success;
}

/// Ports lws-ui [ControllerUpgradeHandler] over contiguous FC16 OTA frames.
final class ControllerUpgradeHandler {
  ControllerUpgradeHandler(this._modbus);

  final ModbusRtuClient _modbus;

  /// Inter-packet gap (lws-ui ~50ms serial gate between OTA writes).
  static const Duration packetGap = Duration(milliseconds: 50);

  /// Transfer [bytes] named [fileName] (must encode HW/SW). Reports 0–99 via [onProgress].
  Future<ControllerUpgradeResult> upgrade({
    required String fileName,
    required Uint8List bytes,
    required void Function(int percent) onProgress,
    bool skipSameVersionCheck = false,
  }) async {
    final hw = BundledFirmwareVersionGate.hardwareVersion(fileName);
    final sw = BundledFirmwareVersionGate.softwareVersion(fileName);
    if (hw == null || sw == null) {
      return const ControllerUpgradeResult(
        ControllerUpgradeOutcome.failed,
        errorMessage: 'invalid firmware file name',
      );
    }
    if (bytes.isEmpty) {
      return const ControllerUpgradeResult(
        ControllerUpgradeOutcome.failed,
        errorMessage: 'empty firmware file',
      );
    }

    if (!skipSameVersionCheck) {
      final deviceHw = await _readU16(FirmwareUpgradeConstants.deviceHw);
      final deviceSw = await _readU16(FirmwareUpgradeConstants.deviceSw);
      if (deviceHw == hw && deviceSw == sw) {
        return const ControllerUpgradeResult(
          ControllerUpgradeOutcome.skippedSameVersion,
        );
      }
    }

    final checkCode = UpgradePacketBuilder.fileCheckCode(bytes);
    final fileLength = bytes.length;

    try {
      return await _modbus.exclusiveSession(() async {
        onProgress(0);
        final info = UpgradePacketBuilder.infoFrame(
          hw: hw,
          sw: sw,
          fileLength: fileLength,
          checkCode: checkCode,
        );
        debugPrint(
          'ControllerUpgradeHandler: info FC16 addr=0x${info.address.toRadixString(16)} '
          'n=${info.words.length} hw=$hw sw=$sw size=$fileLength',
        );
        final infoOk = await _modbus.writeHoldingRegisters(
          info.address,
          info.words,
        );
        if (!infoOk) {
          return const ControllerUpgradeResult(
            ControllerUpgradeOutcome.failed,
            errorMessage: 'firmware info write failed',
          );
        }
        await Future<void>.delayed(packetGap);

        final startedAt = DateTime.now();
        var lastProgressAt = startedAt;
        var offset = 0;

        while (offset < fileLength) {
          final now = DateTime.now();
          if (offset == 0 &&
              now.difference(startedAt) >
                  FirmwareUpgradeConstants.upgradeTimeout) {
            return const ControllerUpgradeResult(
              ControllerUpgradeOutcome.failed,
              errorMessage: 'upgrade timeout before first packet',
            );
          }
          if (now.difference(lastProgressAt) >
              FirmwareUpgradeConstants.stallTimeout) {
            return const ControllerUpgradeResult(
              ControllerUpgradeOutcome.failed,
              errorMessage: 'upgrade stalled',
            );
          }

          final chunkLen = (fileLength - offset)
              .clamp(0, FirmwareUpgradeConstants.packetMaxBytes);
          final chunk = Uint8List.sublistView(bytes, offset, offset + chunkLen);
          final frame = UpgradePacketBuilder.dataFrame(
            hw: hw,
            sw: sw,
            fileLength: fileLength,
            checkCode: checkCode,
            offset: offset,
            chunk: chunk,
          );
          final ok = await _modbus.writeHoldingRegisters(
            frame.address,
            frame.words,
          );
          if (!ok) {
            return ControllerUpgradeResult(
              ControllerUpgradeOutcome.failed,
              errorMessage:
                  'firmware data write failed at offset=$offset n=${frame.words.length}',
            );
          }
          offset += chunkLen;
          lastProgressAt = DateTime.now();
          final percent = ((offset * 100) ~/ fileLength).clamp(0, 99);
          onProgress(percent);
          await Future<void>.delayed(packetGap);
        }

        final end = UpgradePacketBuilder.endFrame(hw: hw, sw: sw);
        final endOk = await _modbus.writeHoldingRegisters(
          end.address,
          end.words,
        );
        if (!endOk) {
          return const ControllerUpgradeResult(
            ControllerUpgradeOutcome.failed,
            errorMessage: 'firmware end write failed',
          );
        }

        final confirm = await _awaitDeviceConfirm(targetHw: hw, targetSw: sw);
        if (confirm) {
          onProgress(100);
          return const ControllerUpgradeResult(
            ControllerUpgradeOutcome.success,
          );
        }
        return const ControllerUpgradeResult(
          ControllerUpgradeOutcome.failed,
          errorMessage: 'device confirm failed',
        );
      });
    } catch (e, st) {
      debugPrint('ControllerUpgradeHandler: $e\n$st');
      return ControllerUpgradeResult(
        ControllerUpgradeOutcome.failed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> _awaitDeviceConfirm({
    required int targetHw,
    required int targetSw,
  }) async {
    final deadline = DateTime.now()
        .add(FirmwareUpgradeConstants.deviceConfirmTimeout);
    const cmdFailGrace = Duration(seconds: 3);
    DateTime? failFirstSeenAt;
    while (DateTime.now().isBefore(deadline)) {
      // Read a consistent view of HW/SW + ota command.
      final status = await _modbus.readGroup('status');
      final cmd = _asInt(status[FirmwareUpgradeConstants.deviceOtaCmd]);
      final deviceHw =
          _asInt(status[FirmwareUpgradeConstants.deviceHw]);
      final deviceSw =
          _asInt(status[FirmwareUpgradeConstants.deviceSw]);

      // Version match means success (board can apply without latch 0x1212
      // until power cycle).
      if (deviceHw == targetHw && deviceSw == targetSw) {
        return true;
      }
      if (cmd == FirmwareUpgradeConstants.upgradeSuccess) {
        return true;
      }
      if (cmd == FirmwareUpgradeConstants.upgradeFail) {
        // Some boards may report failure transiently while applying.
        final seenAt = failFirstSeenAt ??= DateTime.now();
        if (DateTime.now().difference(seenAt) >= cmdFailGrace) {
          return false;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // Boards often apply without latching 0x1212 until power cycle.
    debugPrint(
      'ControllerUpgradeHandler: confirm timeout; treating as success',
    );
    return true;
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  Future<int?> _readU16(String id) async {
    final v = await _modbus.readAttribute(id);
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return null;
  }
}
