import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  AppServices servicesWith(ModbusRtuClient modbus) {
    return AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: modbus,
    );
  }

  bool wroteAutoWireOn(List<(String, Object?)> writes) => writes.any(
        (e) =>
            e.$1 == DeviceControlIds.controlField1 &&
            e.$2 is num &&
            ((e.$2 as num).toInt() & (1 << 4)) != 0,
      );

  test('ensureAutoWireFeedDefault writes ON when currently off', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = false
      ..keySwitchOn = true;

    await controller.ensureAutoWireFeedDefault();
    expect(controller.autoWireFeed, isTrue);
    expect(wroteAutoWireOn(modbus.writes), isTrue);
  });

  test('ensureAutoWireFeedDefault force-writes ON when already true', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = true
      ..keySwitchOn = true;

    await controller.ensureAutoWireFeedDefault();
    expect(controller.autoWireFeed, isTrue);
    expect(wroteAutoWireOn(modbus.writes), isTrue);
  });

  test('ensureAutoWireFeedDefault skips when e-stop active', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = false
      ..emergencyStop = true;

    await controller.ensureAutoWireFeedDefault();
    expect(controller.autoWireFeed, isFalse);
    expect(modbus.writes, isEmpty);
  });

  test('ensureAutoWireFeedDefault does not toggle busy', () async {
    final modbus = _SlowField1Modbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = false
      ..keySwitchOn = true;

    final busyWhileWriting = <bool>[];
    controller.addListener(() {
      busyWhileWriting.add(controller.busy);
    });

    final done = controller.ensureAutoWireFeedDefault();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.busy, isFalse);
    expect(controller.autoWireFeed, isTrue);
    await done;
    expect(controller.busy, isFalse);
    expect(busyWhileWriting, isNot(contains(true)));
  });

  test('ensureAutoWireFeedDefault ignores stale watch OFF while forcing',
      () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = true
      ..keySwitchOn = true;

    // Simulate ensure in-flight holding latch via a deferred write gate.
    final gate = Completer<void>();
    modbus.writeGate = gate.future;
    final pending = controller.ensureAutoWireFeedDefault();
    await Future<void>.delayed(Duration.zero);
    controller.applyChanges(const [
      ModbusAttributeChange(
        id: DeviceControlIds.wireManualMode,
        value: false,
      ),
    ]);
    expect(controller.autoWireFeed, isTrue);
    gate.complete();
    await pending;
    expect(controller.autoWireFeed, isTrue);
  });

  test('start applies ensure after stale watch prime so UI stays ON', () async {
    final modbus = _StaleAutoWirePrimeModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..keySwitchOn = true;

    await controller.start();
    expect(controller.autoWireFeed, isTrue);
  });

  test('gear/thickness arc follows the Dashboard circle continuously', () {
    expect(ProcessModeDimens.linearArcPad(0), 24);
    expect(ProcessModeDimens.linearArcPad(1), 34);
    expect(ProcessModeDimens.linearArcPad(2), 44);
    expect(QuickModePickerDimens.linearArcPad(1), 34);

    const radius = 300.0;
    double inset(double distance) => QuickModePickerDimens.circularArcInset(
          signedDistanceFromCenter: distance,
          radius: radius,
        );

    expect(inset(0), 0);
    expect(inset(1), closeTo(radius - 294.72699, 0.0001));
    expect(inset(-1), closeTo(inset(1), 0.0001));
    expect(inset(0.499), lessThan(inset(0.501)));
    expect((inset(0.501) - inset(0.499)).abs(), lessThan(0.1));

    final gearOffset = QuickModePickerDimens.circularArcHorizontalOffset(
      signedDistanceFromCenter: 1,
      radius: radius,
      scaleOnLeft: true,
    );
    final thicknessOffset = QuickModePickerDimens.circularArcHorizontalOffset(
      signedDistanceFromCenter: 1,
      radius: radius,
      scaleOnLeft: false,
    );
    expect(gearOffset, greaterThan(0));
    expect(thicknessOffset, closeTo(-gearOffset, 0.0001));
  });
}

final class _RecordingModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];
  Future<void>? writeGate;

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<T> runCommandQueued<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    final gate = writeGate;
    if (gate != null) {
      await gate;
    }
    writes.add((id, value));
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}

/// Holds [writeAttribute] long enough for listeners to observe [busy].
final class _SlowField1Modbus extends _RecordingModbus {
  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return super.writeAttribute(id, value);
  }
}

/// Sync-primes auto-wire OFF on listen (HAL watch prime), then allows
/// [DeviceControlController.start] to force ON afterward.
final class _StaleAutoWirePrimeModbus extends _RecordingModbus {
  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async {
    late final StreamController<List<ModbusAttributeChange>> controller;
    controller = StreamController<List<ModbusAttributeChange>>.broadcast(
      onListen: () {
        controller.add(const [
          ModbusAttributeChange(
            id: DeviceControlIds.wireManualMode,
            value: false,
            previous: null,
            kind: ModbusChangeKind.primed,
          ),
        ]);
      },
    );
    return controller.stream;
  }
}
