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

  test('ensureAutoWireFeedDefault writes ON when currently off', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = false
      ..keySwitchOn = true;

    await controller.ensureAutoWireFeedDefault();
    expect(controller.autoWireFeed, isTrue);
    expect(
      modbus.writes.any(
        (e) => e.$1 == DeviceControlIds.wireManualMode && e.$2 == true,
      ),
      isTrue,
    );
  });

  test('ensureAutoWireFeedDefault force-writes ON when already true', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..autoWireFeed = true
      ..keySwitchOn = true;

    await controller.ensureAutoWireFeedDefault();
    expect(controller.autoWireFeed, isTrue);
    expect(
      modbus.writes.any(
        (e) => e.$1 == DeviceControlIds.wireManualMode && e.$2 == true,
      ),
      isTrue,
    );
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

  test('offset arc pads match lws-ui OffsetWheelBuilder', () {
    expect(ProcessModeDimens.linearArcPad(0), 24);
    expect(ProcessModeDimens.linearArcPad(1), 34);
    expect(ProcessModeDimens.linearArcPad(2), 44);
    expect(QuickModePickerDimens.linearArcPad(1), 34);
    expect(QuickModePickerDimens.unselectedOffset(0), 8);
    expect(QuickModePickerDimens.unselectedOffset(1), 16);
    expect(QuickModePickerDimens.unselectedOffset(2), 40);
  });
}

final class _RecordingModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
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
