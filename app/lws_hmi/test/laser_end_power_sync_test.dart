import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_threshold_codec.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_thresholds_controller.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  test('syncAndSendLaserTerminationPower sets end = laser × 0.97', () async {
    final dir = await Directory.systemTemp.createTemp('laser-end-sync-');
    addTearDown(() => dir.delete(recursive: true));
    final store = AdvancedSettingsStore(
      preferencePath: '${dir.path}/advanced-settings.json',
    );
    store.warmRead();
    final modbus = _RecordingModbus();
    final services = AppServices(
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
    final thresholds = AdvancedSettingsThresholdsController(
      store: store,
      services: services,
    );
    addTearDown(thresholds.dispose);
    thresholds.warmFromStore();
    expect(thresholds.values.laserEndPower, 10);

    await thresholds.syncAndSendLaserTerminationPower(55);

    expect(thresholds.values.laserEndPower, closeTo(53.35, 1e-9));
    expect(store.thresholds.laserEndPower, closeTo(53.35, 1e-9));
    final endWrites = modbus.writes
        .where((e) => e.$1 == AdvancedSettingsModbusIds.laserEndPower)
        .map((e) => e.$2)
        .toList();
    expect(
      endWrites,
      contains(
        AdvancedSettingsThresholdCodec.toWire(
          AdvancedSettingsModbusIds.laserEndPower,
          53.35,
        ),
      ),
    );
  });
}

final class _RecordingModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    writes.add((id, value));
    return true;
  }

  @override
  Future<Object?> readAttribute(String id) async => null;

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}
