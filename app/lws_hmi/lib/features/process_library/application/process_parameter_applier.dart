import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_wire_codec.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// How a process preset is pushed to Modbus (lws-ui parity).
enum ProcessApplyMode {
  /// Same-mode param tweak (`sendProcessConfigData` / `sendData`): process group only.
  liveTune,

  /// Tab / mode switch / laser-enable prep (`selectModel`): type when changed + process.
  modeSwitch,
}

enum ProcessApplyFailure {
  busy,
  baselineReadFailed,

  /// Modbus status unavailable (read failed / missing bits).
  statusUnavailable,

  /// Laser enable or laser emission is active.
  unsafeMachineState,

  /// Wire feeding feedback is on.
  wireFeedingActive,
  processWriteFailed,
  processReadFailed,
  processReadbackFailed,
  processTypeWriteFailed,
  processTypeReadFailed,
  processTypeReadbackFailed,
  partialApply,
}

final class ProcessApplyResult {
  const ProcessApplyResult.success() : failure = null;
  const ProcessApplyResult.failure(this.failure);

  final ProcessApplyFailure? failure;
  bool get isSuccess => failure == null;
}

final class ProcessParameterApplier {
  const ProcessParameterApplier({
    required this.modbus,
    required this.interlockFailure,
  });

  final ModbusRtuClient modbus;

  /// `null` when safe to apply; otherwise a typed [ProcessApplyFailure].
  final Future<ProcessApplyFailure?> Function() interlockFailure;

  /// Applies [preset] to Modbus.
  ///
  /// [mode] defaults to [ProcessApplyMode.liveTune] (field-edit / `sendData`).
  /// [allowLiveTune] `false` forces [ProcessApplyMode.modeSwitch] for legacy callers.
  Future<ProcessApplyResult> apply(
    ProcessPreset preset, {
    ProcessApplyMode mode = ProcessApplyMode.liveTune,
    bool allowLiveTune = true,
  }) async {
    if (!allowLiveTune) {
      mode = ProcessApplyMode.modeSwitch;
    }
    ProcessParameterValidator.validate(preset);
    var last = const ProcessApplyResult.failure(
      ProcessApplyFailure.baselineReadFailed,
    );
    // Transient RTU gaps are common on enable; retry only baseline/read failures.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        last = await modbus.exclusiveSession(
          () => _applyExclusive(preset, mode: mode),
        );
      } catch (_) {
        last = const ProcessApplyResult.failure(
          ProcessApplyFailure.baselineReadFailed,
        );
      }
      if (last.isSuccess ||
          last.failure != ProcessApplyFailure.baselineReadFailed) {
        return last;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 80 * (attempt + 1)),
        );
      }
    }
    return last;
  }

  Future<ProcessApplyResult> _applyExclusive(
    ProcessPreset preset, {
    required ProcessApplyMode mode,
  }) async {
    final baseline = await _readProcessGroup();
    if (baseline == null) {
      debugPrint('ProcessApply: baselineReadFailed');
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
    final expected = ProcessParameterWireCodec.buildWriteValues(
      preset: preset,
      baseline: baseline,
    );
    final interval = expected['process.spot_welding_interval'];
    final duration = expected['process.spot_welding_duration'];
    final modbusType = preset.processType.modbusProcessType;
    debugPrint(
      'ProcessApply: start mode=${mode.name} type=$modbusType '
      'interval=$interval duration=$duration',
    );

    if (mode == ProcessApplyMode.liveTune) {
      return _liveTuneWrite(expected);
    }
    return _modeSwitchWrite(
      preset: preset,
      baseline: baseline,
      expected: expected,
      modbusType: modbusType,
      interval: interval,
      duration: duration,
    );
  }

  /// lws-ui `sendProcessConfigData`: write process group only, no readback.
  Future<ProcessApplyResult> _liveTuneWrite(Map<String, double> expected) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await modbus.writeGroup('process', expected)) {
        debugPrint('ProcessApply: liveTune ok');
        return const ProcessApplyResult.success();
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 40 * (attempt + 1)),
        );
      }
    }
    debugPrint('ProcessApply: liveTune processWriteFailed');
    return const ProcessApplyResult.failure(
      ProcessApplyFailure.processWriteFailed,
    );
  }

  Future<ProcessApplyResult> _modeSwitchWrite({
    required ProcessPreset preset,
    required Map<String, double> baseline,
    required Map<String, double> expected,
    required int modbusType,
    required double? interval,
    required double? duration,
  }) async {
    final blocked = await interlockFailure();
    if (blocked != null) {
      debugPrint('ProcessApply: blocked=$blocked');
      return ProcessApplyResult.failure(blocked);
    }

    final control = await _readGroup('control');
    final previousType = control?['control.process_type'];
    if (previousType is! num) {
      debugPrint('ProcessApply: baselineReadFailed (process_type)');
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
    final prevTypeInt = previousType.toInt();
    final typeChanged = prevTypeInt != modbusType;

    if (typeChanged) {
      debugPrint(
        'ProcessApply: write process_type $prevTypeInt -> $modbusType',
      );
      if (!await _writeProcessModeFrame(control!, modbusType)) {
        return const ProcessApplyResult.failure(
          ProcessApplyFailure.processTypeWriteFailed,
        );
      }
      final typeResult = await _verifyTypeReadback(
        control: control,
        modbusType: modbusType,
        previousType: prevTypeInt,
      );
      if (typeResult != null) {
        return typeResult;
      }
    } else {
      debugPrint('ProcessApply: skip process_type (already $modbusType)');
    }

    debugPrint(
      'ProcessApply: write process group '
      '(interval=$interval duration=$duration)',
    );
    final writeOk = await _writeProcessWithRetry(expected);
    if (!writeOk) {
      debugPrint('ProcessApply: processWriteFailed');
      return ProcessApplyResult.failure(
        await _rollback(baseline, prevTypeInt)
            ? ProcessApplyFailure.processWriteFailed
            : ProcessApplyFailure.partialApply,
      );
    }

    final readbackResult = await _verifyProcessReadback(
      expected: expected,
      baseline: baseline,
      previousType: prevTypeInt,
    );
    if (readbackResult != null) {
      return readbackResult;
    }

    debugPrint(
      'ProcessApply: ok type=$modbusType interval=$interval',
    );
    return const ProcessApplyResult.success();
  }

  Future<bool> _writeProcessWithRetry(Map<String, double> expected) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await modbus.writeGroup('process', expected)) {
        return true;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 40 * (attempt + 1)),
        );
      }
    }
    return false;
  }

  Future<ProcessApplyResult?> _verifyTypeReadback({
    required Map<String, Object?> control,
    required int modbusType,
    required int previousType,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final typeReadback =
          (await _readGroup('control'))?['control.process_type'];
      if (typeReadback == null) {
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 40 * (attempt + 1)),
          );
          continue;
        }
        debugPrint('ProcessApply: processTypeReadFailed');
        final typeRestored =
            await _writeProcessModeFrame(control, previousType);
        return ProcessApplyResult.failure(
          typeRestored
              ? ProcessApplyFailure.processTypeReadFailed
              : ProcessApplyFailure.partialApply,
        );
      }
      final actualType = typeReadback is num ? typeReadback.toInt() : null;
      if (actualType == modbusType) {
        return null;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 40 * (attempt + 1)),
        );
        continue;
      }
      debugPrint(
        'ProcessApply: processTypeReadbackFailed actual=$actualType',
      );
      final typeRestored =
          await _writeProcessModeFrame(control, previousType);
      return ProcessApplyResult.failure(
        typeRestored
            ? ProcessApplyFailure.processTypeReadbackFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    return null;
  }

  Future<ProcessApplyResult?> _verifyProcessReadback({
    required Map<String, double> expected,
    required Map<String, double> baseline,
    required int previousType,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final processReadback = await _readProcessGroup();
      if (processReadback == null) {
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 40 * (attempt + 1)),
          );
          continue;
        }
        debugPrint('ProcessApply: processReadFailed');
        return ProcessApplyResult.failure(
          await _rollback(baseline, previousType)
              ? ProcessApplyFailure.processReadFailed
              : ProcessApplyFailure.partialApply,
        );
      }
      if (_matches(expected, processReadback)) {
        return null;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 40 * (attempt + 1)),
        );
        continue;
      }
      debugPrint(
        'ProcessApply: processReadbackFailed '
        'interval=${processReadback['process.spot_welding_interval']}',
      );
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType)
            ? ProcessApplyFailure.processReadbackFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    return null;
  }

  /// lws-ui `createDeviceControlData`: FC16 start 0x0050, count 5.
  ///
  /// Keep the four hardware-profile words read from the controller and replace
  /// only process type. Do not use the full `control` group (0x0050..0x0058):
  /// that would also rewrite live laser/gas/wire bits.
  Future<bool> _writeProcessModeFrame(
    Map<String, Object?> control,
    int processType,
  ) async {
    const ids = <String>[
      'control.accessory_model_1',
      'control.accessory_model_2',
      'control.gun_drive_type',
      'control.gun_swing_range_mode',
    ];
    final words = <int>[];
    for (final id in ids) {
      final value = control[id];
      if (value is! num) {
        debugPrint('ProcessApply: mode frame missing $id');
        return false;
      }
      words.add(value.toInt());
    }
    words.add(processType);
    debugPrint(
      'ProcessApply: mode frame 0x0050 n=5 '
      'words=$words',
    );
    return modbus.writeHoldingRegisters(0x0050, words);
  }

  static bool _matches(
    Map<String, double> expected,
    Map<String, double> actual,
  ) {
    for (final entry in expected.entries) {
      final value = actual[entry.key];
      if (value == null || (value - entry.value).abs() > 0.0001) {
        return false;
      }
    }
    return true;
  }

  Future<Map<String, Object?>?> _readGroup(String group) async {
    try {
      return await modbus.readGroup(group);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>?> _readProcessGroup() async {
    final raw = await _readGroup('process');
    if (raw == null) {
      return null;
    }
    final values = <String, double>{};
    for (final spec in ProcessParameterCatalog.specs) {
      final value = raw[spec.key];
      if (value is! num) {
        return null;
      }
      values[spec.key] = value.toDouble();
    }
    return values;
  }

  Future<bool> _rollback(
    Map<String, double> baseline,
    int previousType,
  ) async {
    final processOk = await modbus.writeGroup('process', baseline);
    final control = await _readGroup('control');
    final typeOk =
        control != null && await _writeProcessModeFrame(control, previousType);
    if (!processOk || !typeOk) {
      return false;
    }
    final process = await _readProcessGroup();
    final type = (await _readGroup('control'))?['control.process_type'];
    return process != null &&
        _matches(baseline, process) &&
        type is num &&
        type.toInt() == previousType;
  }
}
