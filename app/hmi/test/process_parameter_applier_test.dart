import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  test('refuses process changes while interlock is unsafe', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      isSafeToApply: () async => false,
    );

    final result = await applier.apply(_preset());

    expect(result.failure, ProcessApplyFailure.unsafeMachineState);
    expect(modbus.groupWrites, 0);
  });

  test('batch writes process values and verifies readback', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      isSafeToApply: () async => true,
    );

    final result = await applier.apply(_preset());

    expect(result.isSuccess, isTrue);
    expect(modbus.groupWrites, 1);
    expect(modbus.attributes['control.process_type'], 0);
    expect(modbus.attributes['process.laser_frequency'], 10.0);
  });

  test('reports mismatched process readback', () async {
    final modbus = _FakeModbus(mismatchReadback: true);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      isSafeToApply: () async => true,
    );

    final result = await applier.apply(_preset());

    expect(result.failure, ProcessApplyFailure.processReadbackFailed);
    expect(modbus.groupWrites, 2);
  });

  test('rolls parameters back when process type write fails', () async {
    final modbus = _FakeModbus(failNewTypeWrite: true);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      isSafeToApply: () async => true,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.spotWelding),
    );

    expect(result.failure, ProcessApplyFailure.processTypeWriteFailed);
    expect(modbus.groupWrites, 2);
    expect(modbus.attributes['process.laser_power'], 10);
    expect(modbus.attributes['control.process_type'], 0);
  });
}

ProcessPreset _preset({
  ProcessType processType = ProcessType.continuousWelding,
}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return ProcessPreset(
    uuid: 'test',
    name: 'Test',
    kind: ProcessPresetKind.quick,
    source: 'bundled',
    isBuiltin: true,
    processType: processType,
    materialType: MaterialType.stainlessSteel,
    thickness: 1,
    gear: 1,
    parameters: ProcessParameters({
      'process.laser_power': 50,
      'process.swing_width': 2.5,
    }),
    createdAtMs: now,
    updatedAtMs: now,
  );
}

final class _FakeModbus extends ModbusRtuClient {
  _FakeModbus({
    this.mismatchReadback = false,
    this.failNewTypeWrite = false,
  }) {
    for (final spec in ProcessParameterCatalog.specs) {
      attributes[spec.key] = 10.0;
    }
    attributes['control.process_type'] = 0;
  }

  final bool mismatchReadback;
  final bool failNewTypeWrite;
  final Map<String, Object?> attributes = {};
  int groupWrites = 0;

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeGroup(
    String groupId,
    Map<String, Object?> values,
  ) async {
    groupWrites += 1;
    attributes.addAll(values);
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    if (!mismatchReadback) {
      return Map<String, Object?>.from(attributes);
    }
    return {
      ...attributes,
      'process.laser_power': 49,
    };
  }

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    if (failNewTypeWrite && id == 'control.process_type' && value == 1) {
      return false;
    }
    attributes[id] = value;
    return true;
  }

  @override
  Future<Object?> readAttribute(String id) async => attributes[id];
}
