import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake RTU transport for poll/watch unit tests (no serial).
class FakeModbusRtuTransport extends ModbusRtuTransport {
  FakeModbusRtuTransport(super.transport);

  /// startAddress → full word list returned for that FC04 start.
  final Map<int, List<int>> inputByStart = {};

  int readInputCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<int>?> readInputRegisters(int startAddress, int count) async {
    readInputCalls++;
    final g = gate;
    if (g != null) {
      await g.future;
    }
    final words = inputByStart[startAddress];
    if (words == null) return null;
    if (words.length < count) return words;
    return words.sublist(0, count);
  }

  @override
  Future<List<int>?> readHoldingRegisters(int startAddress, int count) async =>
      null;

  @override
  Future<bool> open() async => true;

  @override
  Future<void> close() async {}
}

ModbusConfig _testConfig({int intervalMs = 20, int commandIntervalMs = 1}) {
  return ModbusConfig(
    version: 1,
    transport: ModbusTransport(
      type: 'rtu',
      device: '/dev/null',
      baud: 115200,
      commandIntervalMs: commandIntervalMs,
    ),
    poll: ModbusPollConfig(intervalMs: intervalMs, discardIfBusy: true),
    groups: {
      'status': const ModbusGroupConfig(
        id: 'status',
        space: 'input',
        start: 0x0000,
        count: 0x14,
        mode: 'continuous',
        chain: 'data',
      ),
      'data': const ModbusGroupConfig(
        id: 'data',
        space: 'input',
        start: 0x0060,
        count: 8,
        mode: 'continuous',
      ),
    },
    attributes: const [
      ModbusAttributeConfig(
        id: 'device.control_card_version',
        access: 'r',
        group: 'status',
        register: ModbusRegisterBinding(space: 'input', address: 0x0002),
        decode: ModbusDecode(type: 'u16'),
      ),
      ModbusAttributeConfig(
        id: 'alarm.gun_comm',
        access: 'r',
        group: 'status',
        register: ModbusRegisterBinding(space: 'input', address: 0x0009),
        decode: ModbusDecode(type: 'bit', bit: 0),
        meta: ModbusAttributeMeta(alarmCode: 'H001', label: 'Gun head communication'),
      ),
      ModbusAttributeConfig(
        id: 'alarm.gun_motor_temp',
        access: 'r',
        group: 'data',
        register: ModbusRegisterBinding(space: 'input', address: 0x0061),
        decode: ModbusDecode(type: 's16', scale: 0.1, unit: 'C'),
      ),
    ],
  );
}

List<int> _statusWords({int firmware = 0x0102, int gunAlarm = 0}) {
  final words = List<int>.filled(0x14, 0);
  words[0x0002] = firmware;
  words[0x0009] = gunAlarm;
  return words;
}

List<int> _dataWords({int motorRaw = 250}) {
  final words = List<int>.filled(8, 0);
  words[1] = motorRaw; // 0x0061
  return words;
}

void main() {
  test('bit decode via readAttribute from group cache', () async {
    final config = _testConfig();
    final fake = FakeModbusRtuTransport(config.transport);
    fake.inputByStart[0x0000] = _statusWords(gunAlarm: 0x0001);
    fake.inputByStart[0x0060] = _dataWords();

    final hal = ModbusHal.fromConfig(config, transport: fake);
    await hal.readGroup('status');
    expect(await hal.readAttribute('alarm.gun_comm'), isTrue);
    expect(await hal.readAttribute('device.control_card_version'), 0x0102);

    fake.inputByStart[0x0000] = _statusWords(gunAlarm: 0);
    await hal.readGroup('status');
    expect(await hal.readAttribute('alarm.gun_comm'), isFalse);
    await hal.close();
  });

  test('watchAttributes emits prime then change-only', () async {
    final config = _testConfig(intervalMs: 30);
    final fake = FakeModbusRtuTransport(config.transport);
    fake.inputByStart[0x0000] = _statusWords(firmware: 1, gunAlarm: 0);
    fake.inputByStart[0x0060] = _dataWords(motorRaw: 250);

    final hal = ModbusHal.fromConfig(config, transport: fake);
    final events = <List<ModbusAttributeChange>>[];
    final sub = hal
        .watchAttributes(ids: ['alarm.gun_comm', 'alarm.gun_motor_temp'])
        .listen(events.add);

    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(events, isNotEmpty);
    final prime = events.first;
    expect(prime.every((c) => c.previous == null), isTrue);
    expect(prime.map((c) => c.id), containsAll(['alarm.gun_comm', 'alarm.gun_motor_temp']));
    final gunPrime = prime.firstWhere((c) => c.id == 'alarm.gun_comm');
    expect(gunPrime.value, isFalse);
    final tempPrime = prime.firstWhere((c) => c.id == 'alarm.gun_motor_temp');
    expect(tempPrime.value, closeTo(25.0, 0.01));

    final before = events.length;
    fake.inputByStart[0x0000] = _statusWords(firmware: 1, gunAlarm: 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final afterPrime = events.skip(before).toList();
    expect(afterPrime, isNotEmpty);
    for (final batch in afterPrime) {
      expect(batch, isNotEmpty);
      // Change-only: must not re-emit unchanged motor temp unless it changed.
      for (final c in batch) {
        expect(c.previous, isNotNull);
      }
      final gun = batch.where((c) => c.id == 'alarm.gun_comm');
      if (gun.isNotEmpty) {
        expect(gun.first.value, isTrue);
        expect(gun.first.previous, isFalse);
      }
    }

    await sub.cancel();
    await hal.stopPolling();
    await hal.close();
  });

  test('watchAttributes emits reminder while alarm stays active', () async {
    final config = ModbusConfig(
      version: 1,
      transport: const ModbusTransport(
        type: 'rtu',
        device: '/dev/null',
        baud: 115200,
        commandIntervalMs: 1,
      ),
      poll: const ModbusPollConfig(
        intervalMs: 25,
        discardIfBusy: true,
        alarmRemind: ModbusAlarmRemindConfig(
          enabled: true,
          defaultIntervalMs: 40,
        ),
      ),
      groups: {
        'status': const ModbusGroupConfig(
          id: 'status',
          space: 'input',
          start: 0x0000,
          count: 0x14,
          mode: 'continuous',
        ),
      },
      attributes: const [
        ModbusAttributeConfig(
          id: 'alarm.gun_comm',
          access: 'r',
          group: 'status',
          register: ModbusRegisterBinding(space: 'input', address: 0x0009),
          decode: ModbusDecode(type: 'bit', bit: 0),
          meta: ModbusAttributeMeta(alarmCode: 'H001', remindIntervalMs: 40),
        ),
      ],
    );
    final fake = FakeModbusRtuTransport(config.transport);
    fake.inputByStart[0x0000] = _statusWords(gunAlarm: 1);

    final hal = ModbusHal.fromConfig(config, transport: fake);
    final reminders = <ModbusAttributeChange>[];
    final sub = hal.watchAttributes(ids: ['alarm.gun_comm']).listen((batch) {
      reminders.addAll(batch.where((c) => c.isReminder));
    });

    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(reminders, isNotEmpty);
    expect(reminders.first.id, 'alarm.gun_comm');
    expect(reminders.first.value, isTrue);
    expect(reminders.first.kind, ModbusChangeKind.reminder);

    await sub.cancel();
    await hal.stopPolling();
    await hal.close();
  });

  test('discard-if-busy skips overlapping ticks', () async {
    final config = _testConfig(intervalMs: 10, commandIntervalMs: 5);
    final fake = FakeModbusRtuTransport(config.transport);
    fake.gate = Completer<void>();
    fake.inputByStart[0x0000] = _statusWords();
    fake.inputByStart[0x0060] = _dataWords();

    final hal = ModbusHal.fromConfig(config, transport: fake);
    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final callsWhileBlocked = fake.readInputCalls;
    expect(callsWhileBlocked, greaterThan(0));
    // While first cycle is gated, further ticks should be discarded.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(fake.readInputCalls, callsWhileBlocked);

    fake.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fake.readInputCalls, greaterThan(callsWhileBlocked));

    await hal.stopPolling();
    await hal.close();
  });

  test('startPolling while already polling is a no-op', () async {
    final config = _testConfig(intervalMs: 25, commandIntervalMs: 1);
    final fake = FakeModbusRtuTransport(config.transport);
    fake.inputByStart[0x0000] = _statusWords();
    fake.inputByStart[0x0060] = _dataWords();

    final hal = ModbusHal.fromConfig(config, transport: fake);
    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final callsAfterFirst = fake.readInputCalls;
    expect(callsAfterFirst, greaterThan(0));

    // Second start must not stop+restart (would cancel mid-cycle / reset timer).
    await hal.startPolling(groupIds: ['status']);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(fake.readInputCalls, greaterThan(callsAfterFirst));

    await hal.stopPolling();
    // After stop, startPolling may run again.
    final callsAfterStop = fake.readInputCalls;
    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fake.readInputCalls, greaterThan(callsAfterStop));

    await hal.stopPolling();
    await hal.close();
  });

  test('concurrent watchAttributes filter by subscriber ids', () async {
    final config = _testConfig(intervalMs: 30);
    final fake = FakeModbusRtuTransport(config.transport);
    fake.inputByStart[0x0000] = _statusWords(firmware: 1, gunAlarm: 0);
    fake.inputByStart[0x0060] = _dataWords(motorRaw: 250);

    final hal = ModbusHal.fromConfig(config, transport: fake);
    final tempEvents = <List<ModbusAttributeChange>>[];
    final alarmEvents = <List<ModbusAttributeChange>>[];
    final tempSub = hal
        .watchAttributes(ids: ['alarm.gun_motor_temp'])
        .listen(tempEvents.add);
    final alarmSub = hal
        .watchAttributes(ids: ['alarm.gun_comm'])
        .listen(alarmEvents.add);

    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(tempEvents, isNotEmpty);
    expect(
      tempEvents.expand((b) => b).every((c) => c.id == 'alarm.gun_motor_temp'),
      isTrue,
    );
    expect(alarmEvents, isNotEmpty);
    expect(
      alarmEvents.expand((b) => b).every((c) => c.id == 'alarm.gun_comm'),
      isTrue,
    );

    final tempBefore = tempEvents.length;
    final alarmBefore = alarmEvents.length;
    fake.inputByStart[0x0000] = _statusWords(firmware: 1, gunAlarm: 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(alarmEvents.length, greaterThan(alarmBefore));
    final alarmOnly = alarmEvents
        .skip(alarmBefore)
        .expand((b) => b)
        .where((c) => c.id == 'alarm.gun_comm' && c.value == true);
    expect(alarmOnly, isNotEmpty);
    // Temperature unchanged → temp subscriber must not get gun_comm.
    final tempAfter = tempEvents.skip(tempBefore).expand((b) => b);
    expect(tempAfter.any((c) => c.id == 'alarm.gun_comm'), isFalse);

    await tempSub.cancel();
    final callsAfterCancel = fake.readInputCalls;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fake.readInputCalls, greaterThan(callsAfterCancel));
    expect(alarmEvents.length, greaterThan(alarmBefore));

    await alarmSub.cancel();
    await hal.stopPolling();
    await hal.close();
  });

  test('formatTemperatureDisplay accepts scaled and raw', () {
    expect(formatTemperatureDisplay(250), '25.0 °C');
    expect(formatTemperatureDisplay(25.0), '25.0 °C');
    expect(formatTemperatureDisplay(-999), '-');
    expect(formatTemperatureDisplay(-99.9), '-');
  });
}
