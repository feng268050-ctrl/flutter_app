import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

enum ProcessApplyFailure {
  busy,
  baselineReadFailed,
  unsafeMachineState,
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
    required this.isSafeToApply,
  });

  final ModbusRtuClient modbus;
  final Future<bool> Function() isSafeToApply;

  Future<ProcessApplyResult> apply(ProcessPreset preset) async {
    ProcessParameterValidator.validate(preset);
    try {
      return await modbus.exclusiveSession(() => _applyExclusive(preset));
    } catch (_) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
  }

  Future<ProcessApplyResult> _applyExclusive(ProcessPreset preset) async {
    final baseline = await _readProcessGroup();
    if (baseline == null) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
    if (!await isSafeToApply()) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.unsafeMachineState,
      );
    }
    final previousType = (await _readGroup('control'))?['control.process_type'];
    if (previousType is! num) {
      return const ProcessApplyResult.failure(
        ProcessApplyFailure.baselineReadFailed,
      );
    }
    final expected = <String, double>{
      ...baseline,
      ...preset.parameters.values,
    };
    if (!await modbus.writeGroup('process', preset.parameters.values)) {
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
    if (!await modbus.writeAttribute(
      'control.process_type',
      preset.processType.wireValue,
    )) {
      return ProcessApplyResult.failure(
        await _rollback(baseline, previousType.toInt())
            ? ProcessApplyFailure.processTypeWriteFailed
            : ProcessApplyFailure.partialApply,
      );
    }
    final typeReadback = (await _readGroup('control'))?['control.process_type'];
    final actualType = typeReadback is num ? typeReadback.toInt() : null;
    if (actualType != preset.processType.wireValue) {
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
