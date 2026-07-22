import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

final class _FakeModbus extends ModbusRtuClient {
  _FakeModbus() : super();

  final _ctrl = StreamController<List<ModbusAttributeChange>>.broadcast();

  @override
  Future<List<ModbusAttributeConfig>> listAttributes() async {
    return [
      ModbusAttributeConfig.fromJson({
        'id': 'alarm.gun_comm',
        'access': 'r',
        'group': 'status',
        'register': {
          'space': 'input',
          'address': '0x0009',
          'count': 1,
        },
        'decode': {'type': 'bit', 'bit': 0, 'active_high': true},
        'meta': {
          'alarm_code': 'H001',
          'label': 'Gun head communication',
        },
      }),
    ];
  }

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async {
    return _ctrl.stream;
  }

  void emit(List<ModbusAttributeChange> changes) => _ctrl.add(changes);
}

void main() {
  test('adapter maps rising / falling / reminder without UI', () async {
    final fake = _FakeModbus();
    final adapter = ModbusAlarmAttributeAdapter(modbus: fake);
    final events = <AlarmSignalEvent>[];
    final sub = adapter.events.listen(events.add);
    await adapter.start();

    fake.emit([
      const ModbusAttributeChange(
        id: 'alarm.gun_comm',
        value: true,
        previous: null,
        kind: ModbusChangeKind.primed,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(events.single.kind, AlarmSignalKind.rising);
    expect(events.single.code, 'H001');

    fake.emit([
      const ModbusAttributeChange(
        id: 'alarm.gun_comm',
        value: true,
        previous: true,
        kind: ModbusChangeKind.reminder,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(events.last.kind, AlarmSignalKind.reminder);

    fake.emit([
      const ModbusAttributeChange(
        id: 'alarm.gun_comm',
        value: false,
        previous: true,
        kind: ModbusChangeKind.changed,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(events.last.kind, AlarmSignalKind.falling);

    await sub.cancel();
    await adapter.dispose();
  });
}
