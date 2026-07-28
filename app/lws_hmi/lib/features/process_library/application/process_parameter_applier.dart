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

  Future<ProcessApplyResult> apply(ProcessPreset preset) async {
    ProcessParameterValidator.validate(preset);
    var last = const ProcessApplyResult.failure(
      ProcessApplyFailure.baselineReadFailed,
    );
    // Transient RTU gaps are common on enable; retry only baseline/read failures.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        last = await modbus.exclusiveSession(() => _applyExclusive(preset));
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

  Future<ProcessApplyResult> _applyExclusive(ProcessPreset preset) async {
    final baseline = await _readProcessGroup();
    if (baseline == null) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
    final blocked = await interlockFailure();
    if (blocked != null) {
      return ProcessApplyResult.failure(blocked);
    }
    final previousType = (await _readGroup('control'))?['control.process_type'];
    if (previousType is! num) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
    final expected = ProcessParameterWireCodec.buildWriteValues(
      preset: preset,
      baseline: baseline,
    );
    if (!await modbus.writeGroup('process', expected)) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.processWriteFailed,
      );
    }
    final processReadback = await _readProcessGroup();
    if (processReadback == null || !_matches(expected, processReadback)) {
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType.toInt())
            ? ProcessApplyFailure.processReadbackFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    final modbusType = preset.processType.modbusProcessType;
    if (!await modbus.writeAttribute(
      'control.process_type',
      modbusType,
    )) {
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType.toInt())
            ? ProcessApplyFailure.processTypeWriteFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    final typeReadback = (await _readGroup('control'))?['control.process_type'];
    final actualType = typeReadback is num ? typeReadback.toInt() : null;
    if (actualType != modbusType) {
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType.toInt())
            ? ProcessApplyFailure.processTypeReadbackFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    return const ProcessApplyResult.success();
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
    final typeOk =
        await modbus.writeAttribute('control.process_type', previousType);
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
