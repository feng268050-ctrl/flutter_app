import 'dart:io';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/catalog/product_alarm_catalog.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/file_alarm_log_repository.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  test('product catalog covers Modbus + lws-ui non-Modbus codes', () {
    final cat = ProductAlarmCatalog.seed();
    expect(cat.contains('H001'), isTrue);
    expect(cat.resolve('H001').severity, AlarmSeverity.high);
    expect(cat.contains('C001'), isTrue);
    expect(cat.resolve('C001').severity, AlarmSeverity.high);
    expect(cat.resolve('C001').title, contains('Communication'));
    expect(cat.contains('L001'), isTrue);
    expect(cat.resolve('L001').title, contains('Lens'));
    expect(cat.contains('C002'), isTrue);
    expect(cat.contains('H034'), isTrue);
    expect(cat.contains('C003'), isTrue);
    expect(cat.contains('C004'), isTrue);
    expect(cat.contains('X006'), isTrue);
    expect(cat.resolve('ZZZ').severity, AlarmSeverity.unknown);
  });

  test('file log inserts on rising and clear empties', () async {
    final dir = await Directory.systemTemp.createTemp('alarm-log-');
    final path = '${dir.path}/alarm-log.json';
    final repo = FileAlarmLogRepository(path: path);
    await repo.insertRising(
      AlarmLogEntry(
        code: 'H001',
        title: 'Gun',
        timestamp: DateTime.utc(2026, 7, 21),
      ),
    );
    expect(await repo.query(), hasLength(1));
    await repo.clear();
    expect(await repo.query(), isEmpty);
    await repo.dispose();
    await dir.delete(recursive: true);
  });

  test('health edge emits C001 rising then falling once each', () async {
    final adapter = ModbusAlarmAttributeAdapter(
      modbus: ModbusRtuClient(),
    );
    final events = <AlarmSignalEvent>[];
    final sub = adapter.events.listen(events.add);

    adapter.debugApplyHealth(const ModbusHealth(ok: true));
    expect(events, isEmpty);

    adapter.debugApplyHealth(
      const ModbusHealth(ok: false, message: 'health window: 5/5 failures'),
    );
    expect(events, hasLength(1));
    expect(events.single.code, kModbusHealthAlarmCode);
    expect(events.single.kind, AlarmSignalKind.rising);
    expect(events.single.active, isTrue);

    adapter.debugApplyHealth(
      const ModbusHealth(ok: false, message: 'still bad'),
    );
    expect(events, hasLength(1), reason: 'no duplicate rising');

    adapter.debugApplyHealth(const ModbusHealth(ok: true));
    expect(events, hasLength(2));
    expect(events.last.kind, AlarmSignalKind.falling);
    expect(events.last.active, isFalse);

    await sub.cancel();
    await adapter.dispose();
  });
}
