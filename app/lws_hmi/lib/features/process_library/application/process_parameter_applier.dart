import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_wire_codec.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

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
  processReadbackFailed,
  processTypeWriteFailed,
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
  /// When [allowLiveTune] is true (default, field-edit / `sendData` parity),
  /// laser/wire interlocks still write the process group but skip
  /// `control.process_type`. Laser-enable paths pass `false` so a stuck enable
  /// bit cannot skip the type write and still report success.
  Future<ProcessApplyResult> apply(
    ProcessPreset preset, {
    bool allowLiveTune = true,
  }) async {
    ProcessParameterValidator.validate(preset);
    var last = const ProcessApplyResult.failure(
      ProcessApplyFailure.baselineReadFailed,
    );
    // Transient RTU gaps are common on enable; retry only baseline/read failures.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        last = await modbus.exclusiveSession(
          () => _applyExclusive(preset, allowLiveTune: allowLiveTune),
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
    required bool allowLiveTune,
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
      'ProcessApply: start type=$modbusType '
      'interval=$interval duration=$duration',
    );

    final blocked = await interlockFailure();
    // lws-ui `sendData` still writes process regs while laser/wire is active;
    // only `control.process_type` must stay idle. Live-tune path: process group
    // only (no type write / no type rollback).
    if (allowLiveTune &&
        (blocked == ProcessApplyFailure.unsafeMachineState ||
            blocked == ProcessApplyFailure.wireFeedingActive)) {
      debugPrint(
        'ProcessApply: liveTune process-only (interlock=$blocked)',
      );
      return _writeProcessGroupOnly(expected);
    }
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

    // lws-ui selectModel writes createDeviceControlData as one FC16 frame:
    // 0x0050..0x0054 (accessories, gun drive/range, process_type), then sends
    // the process frame. A single 0x0054 write updates the register mirror on
    // some controllers but does not latch the internal work mode.
    debugPrint(
      'ProcessApply: write process_type $previousType -> $modbusType',
    );
    if (!await _writeProcessModeFrame(control!, modbusType)) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.processTypeWriteFailed,
      );
    }
    final typeReadback = (await _readGroup('control'))?['control.process_type'];
    final actualType = typeReadback is num ? typeReadback.toInt() : null;
    if (actualType != modbusType) {
      debugPrint(
        'ProcessApply: processTypeReadbackFailed actual=$actualType',
      );
      final typeRestored =
          await _writeProcessModeFrame(control, previousType.toInt());
      return ProcessApplyResult.failure(
        typeRestored
            ? ProcessApplyFailure.processTypeReadbackFailed
            : ProcessApplyFailure.partialApply,
      );
    }

    debugPrint(
      'ProcessApply: write process group '
      '(interval=$interval duration=$duration)',
    );
    if (!await modbus.writeGroup('process', expected)) {
      debugPrint('ProcessApply: processWriteFailed');
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType.toInt())
            ? ProcessApplyFailure.processWriteFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    final processReadback = await _readProcessGroup();
    if (processReadback == null || !_matches(expected, processReadback)) {
      debugPrint(
        'ProcessApply: processReadbackFailed '
        'interval=${processReadback?['process.spot_welding_interval']}',
      );
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType.toInt())
            ? ProcessApplyFailure.processReadbackFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    debugPrint(
      'ProcessApply: ok type=$modbusType '
      'interval=${processReadback['process.spot_welding_interval']}',
    );
    return const ProcessApplyResult.success();
  }

  Future<ProcessApplyResult> _writeProcessGroupOnly(
    Map<String, double> expected,
  ) async {
    if (!await modbus.writeGroup('process', expected)) {
      debugPrint('ProcessApply: liveTune processWriteFailed');
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.processWriteFailed,
      );
    }
    final processReadback = await _readProcessGroup();
    if (processReadback == null || !_matches(expected, processReadback)) {
      debugPrint(
        'ProcessApply: liveTune processReadbackFailed '
        'interval=${processReadback?['process.spot_welding_interval']}',
      );
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.processReadbackFailed,
      );
    }
    debugPrint(
      'ProcessApply: liveTune ok '
      'interval=${processReadback['process.spot_welding_interval']}',
    );
    return const ProcessApplyResult.success();
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
