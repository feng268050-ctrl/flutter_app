import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  test('liveTune writes process only without interlock', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(
        processType: ProcessType.spotWelding,
        parameters: const {
          'process.laser_power': 50,
          'process.spot_welding_interval': 1500,
          'process.spot_welding_duration': 200,
        },
      ),
      mode: ProcessApplyMode.liveTune,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.groupWrites, 1);
    expect(modbus.modeFrameWrites, 0);
    expect(modbus.processGroupReads, 1);
    expect(modbus.attributes['control.process_type'], 0);
    expect(modbus.attributes['process.spot_welding_interval'], 1500);
    expect(modbus.attributes['process.spot_welding_duration'], 200);
  });

  test('liveTune writes process while laser interlock is active', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
    );

    final result = await applier.apply(
      _preset(
        processType: ProcessType.spotWelding,
        parameters: const {
          'process.laser_power': 50,
          'process.spot_welding_interval': 1500,
          'process.spot_welding_duration': 200,
        },
      ),
      mode: ProcessApplyMode.liveTune,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.groupWrites, 1);
    expect(modbus.modeFrameWrites, 0);
    expect(modbus.attributes['control.process_type'], 0);
    expect(modbus.attributes['process.spot_welding_interval'], 1500);
  });

  test('liveTune retries transient process write failure', () async {
    final modbus = _FakeModbus(failProcessWrites: 1);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(parameters: const {'process.laser_power': 50}),
      mode: ProcessApplyMode.liveTune,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.groupWrites, 1);
  });

  test('modeSwitch refuses when interlock is unsafe', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.spotWelding),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.failure, ProcessApplyFailure.unsafeMachineState);
    expect(modbus.groupWrites, 0);
  });

  test('refuses apply when status interlock is unavailable', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => ProcessApplyFailure.statusUnavailable,
    );

    final result = await applier.apply(
      _preset(),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.failure, ProcessApplyFailure.statusUnavailable);
    expect(modbus.groupWrites, 0);
  });

  test('modeSwitch batch writes process values and verifies readback', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.groupWrites, 1);
    expect(modbus.modeFrameWrites, 0);
    expect(modbus.attributes['control.process_type'], 0);
    expect(modbus.attributes['process.laser_power'], 50);
    expect(modbus.attributes['process.laser_duty_cycle'], 100);
    expect(modbus.attributes['process.laser_frequency'], 5000);
    expect(modbus.attributes['process.piercing_power'], 50);
    expect(modbus.attributes['process.wire_feeding_delay'], 0);
    expect(modbus.attributes['process.piercing_duration'], 0);
  });

  test('modeSwitch skips type frame when type unchanged', () async {
    final modbus = _FakeModbus();
    modbus.attributes['control.process_type'] = 0;
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.continuousWelding),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.modeFrameWrites, 0);
    expect(modbus.groupWrites, 1);
  });

  test('writes modbus process type for wide cleaning (2, not wire 3)',
      () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.wideCleaning),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.lastModeFrame, [101, 102, 1, 7, 2]);
    expect(modbus.attributes['control.process_type'], 2);
    expect(modbus.attributes['process.swing_width'], 0.5);
  });

  test('retries baseline read after transient process group failure', () async {
    final modbus = _FakeModbus(failBaselineReads: 2);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.isSuccess, isTrue);
    expect(modbus.processGroupReads, greaterThanOrEqualTo(3));
  });

  test('does not mutate process when process type write fails', () async {
    final modbus = _FakeModbus(failNewTypeWrite: true);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.spotWelding),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.failure, ProcessApplyFailure.processTypeWriteFailed);
    expect(modbus.groupWrites, 0);
    expect(modbus.modeFrameWrites, 1);
    expect(modbus.attributes['process.laser_power'], 10);
    expect(modbus.attributes['control.process_type'], 0);
  });

  test('rolls type back when process readback mismatches', () async {
    final modbus = _FakeModbus(mismatchReadbackOnce: true);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.spotWelding),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.failure, ProcessApplyFailure.processReadbackFailed);
    expect(modbus.groupWrites, 2);
    expect(modbus.attributes['control.process_type'], 0);
    expect(modbus.attributes['process.laser_power'], 10);
  });

  test('modeSwitch reports processReadFailed when readback is null', () async {
    final modbus = _FakeModbus(failProcessReadbackReads: 3);
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => null,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.spotWelding),
      mode: ProcessApplyMode.modeSwitch,
    );

    expect(result.failure, ProcessApplyFailure.processReadFailed);
    expect(modbus.groupWrites, 2);
  });

  test('allowLiveTune false maps to modeSwitch', () async {
    final modbus = _FakeModbus();
    final applier = ProcessParameterApplier(
      modbus: modbus,
      interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
    );

    final result = await applier.apply(
      _preset(processType: ProcessType.spotWelding),
      allowLiveTune: false,
    );

    expect(result.failure, ProcessApplyFailure.unsafeMachineState);
    expect(modbus.groupWrites, 0);
  });
}

ProcessPreset _preset({
  ProcessType processType = ProcessType.continuousWelding,
  Map<String, double> parameters = const {
    'process.laser_power': 50,
    'process.swing_width': 2.5,
  },
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
    thickness: processType.isCleaning ? null : 1,
    gear: 1,
    parameters: ProcessParameters(Map<String, double>.from(parameters)),
    createdAtMs: now,
    updatedAtMs: now,
  );
}

final class _FakeModbus extends ModbusRtuClient {
  _FakeModbus({
    this.mismatchReadbackOnce = false,
    this.failNewTypeWrite = false,
    this.failBaselineReads = 0,
    this.failProcessWrites = 0,
    this.failProcessReadbackReads = 0,
  }) {
    for (final spec in ProcessParameterCatalog.specs) {
      attributes[spec.key] = 10.0;
    }
    attributes['control.accessory_model_1'] = 101;
    attributes['control.accessory_model_2'] = 102;
    attributes['control.gun_drive_type'] = 1;
    attributes['control.gun_swing_range_mode'] = 7;
    attributes['control.process_type'] = 0;
    _processWritesLeft = failProcessWrites;
    _processReadbackFailsLeft = failProcessReadbackReads;
    if (mismatchReadbackOnce) {
      _mismatchReadsLeft = 5;
    }
  }

  final bool mismatchReadbackOnce;
  final bool failNewTypeWrite;
  final int failBaselineReads;
  final int failProcessWrites;
  final int failProcessReadbackReads;
  final Map<String, Object?> attributes = {};
  int groupWrites = 0;
  int modeFrameWrites = 0;
  int processGroupReads = 0;
  int _mismatchReadsLeft = 1;
  int _processWritesLeft = 0;
  int _processReadbackFailsLeft = 0;
  List<int>? lastModeFrame;

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<T> runCommandQueued<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeGroup(
    String groupId,
    Map<String, Object?> values,
  ) async {
    if (_processWritesLeft > 0) {
      _processWritesLeft -= 1;
      return false;
    }
    groupWrites += 1;
    attributes.addAll(values);
    return true;
  }

  @override
  Future<bool> writeHoldingRegisters(
    int address,
    List<int> words,
  ) async {
    expect(address, 0x0050);
    expect(words, hasLength(5));
    modeFrameWrites += 1;
    lastModeFrame = List<int>.from(words);
    if (failNewTypeWrite && words.last == 1) {
      return false;
    }
    attributes['control.accessory_model_1'] = words[0];
    attributes['control.accessory_model_2'] = words[1];
    attributes['control.gun_drive_type'] = words[2];
    attributes['control.gun_swing_range_mode'] = words[3];
    attributes['control.process_type'] = words[4];
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    if (groupId == 'process') {
      processGroupReads += 1;
      if (processGroupReads <= failBaselineReads) {
        throw StateError('transient process read');
      }
      if (_processReadbackFailsLeft > 0 &&
          processGroupReads > failBaselineReads + 1) {
        _processReadbackFailsLeft -= 1;
        throw StateError('transient process readback');
      }
      if (mismatchReadbackOnce && _mismatchReadsLeft > 0) {
        final writtenPower = attributes['process.laser_power'];
        if (writtenPower is num && writtenPower.toDouble() == 50.0) {
          _mismatchReadsLeft -= 1;
          return {
            ...attributes,
            'process.laser_power': 49,
          };
        }
      }
    }
    return Map<String, Object?>.from(attributes);
  }

  @override
  Future<Object?> readAttribute(String id) async => attributes[id];
}
