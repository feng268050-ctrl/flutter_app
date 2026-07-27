import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake RTU with holding read/write capture for encode + FC16 path tests.
class FakeWriteTransport extends ModbusRtuTransport {
  FakeWriteTransport(super.transport);

  final Map<int, List<int>> holdingByStart = {};
  final List<(int start, List<int> words)> writes = [];
  int writeSingleCalls = 0;
  int writeMultipleCalls = 0;

  @override
  Future<bool> open() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<int>?> readInputRegisters(int startAddress, int count) async =>
      null;

  @override
  Future<List<int>?> readHoldingRegisters(int startAddress, int count) async {
    final words = holdingByStart[startAddress];
    if (words == null) return List<int>.filled(count, 0);
    if (words.length < count) {
      return [...words, ...List<int>.filled(count - words.length, 0)];
    }
    return words.sublist(0, count);
  }

  @override
  Future<bool> writeSingleRegister(int address, int value) async {
    writeSingleCalls++;
    writes.add((address, [value]));
    holdingByStart[address] = [value];
    return true;
  }

  @override
  Future<bool> writeMultipleRegisters(int startAddress, List<int> values) async {
    writeMultipleCalls++;
    writes.add((startAddress, List<int>.from(values)));
    holdingByStart[startAddress] = List<int>.from(values);
    return true;
  }
}

ModbusConfig _writeConfig({
  bool writeSingle = false,
  bool writeMultiple = true,
}) {
  return ModbusConfig(
    version: 1,
    transport: const ModbusTransport(
      type: 'rtu',
      device: '/dev/null',
      baud: 115200,
    ),
    capabilities: ModbusCapabilities(
      readHolding: true,
      readInput: true,
      writeSingle: writeSingle,
      writeMultiple: writeMultiple,
    ),
    groups: {
      'process': const ModbusGroupConfig(
        id: 'process',
        space: 'holding',
        start: 0x0060,
        count: 8,
        mode: 'on_demand',
      ),
      'control': const ModbusGroupConfig(
        id: 'control',
        space: 'holding',
        start: 0x0050,
        count: 9,
        mode: 'on_demand',
      ),
    },
    attributes: const [
      ModbusAttributeConfig(
        id: 'process.laser_power',
        access: 'rw',
        group: 'process',
        register: ModbusRegisterBinding(space: 'holding', address: 0x0060),
        decode: ModbusDecode(type: 'u16', scale: 0.01, unit: '%'),
      ),
      ModbusAttributeConfig(
        id: 'process.swing_width',
        access: 'rw',
        group: 'process',
        register: ModbusRegisterBinding(space: 'holding', address: 0x0067),
        decode: ModbusDecode(type: 'u16', scale: 0.1, unit: 'mm'),
      ),
      ModbusAttributeConfig(
        id: 'control.field_1',
        access: 'rw',
        group: 'control',
        register: ModbusRegisterBinding(space: 'holding', address: 0x0058),
        decode: ModbusDecode(type: 'u16'),
      ),
      ModbusAttributeConfig(
        id: 'control.laser_enable',
        access: 'rw',
        group: 'control',
        register: ModbusRegisterBinding(space: 'holding', address: 0x0058),
        decode: ModbusDecode(type: 'bit', bit: 0),
      ),
      ModbusAttributeConfig(
        id: 'upgrade.data',
        access: 'w',
        group: 'control',
        register: ModbusRegisterBinding(
          space: 'holding',
          address: 0x0050,
          count: 4,
        ),
        decode: ModbusDecode(type: 'u16_array'),
      ),
    ],
  );
}

void main() {
  test('writeAttribute encodes percent power with scale 0.01', () async {
    final config = _writeConfig();
    final fake = FakeWriteTransport(config.transport);
    final hal = ModbusHal.fromConfig(config, transport: fake);

    await hal.writeAttribute('process.laser_power', 55);
    expect(fake.writeMultipleCalls, 1);
    expect(fake.writeSingleCalls, 0);
    expect(fake.writes.last.$1, 0x0060);
    expect(fake.writes.last.$2, [5500]);
  });

  test('writeAttribute encodes scaled swing width', () async {
    final config = _writeConfig();
    final fake = FakeWriteTransport(config.transport);
    final hal = ModbusHal.fromConfig(config, transport: fake);

    await hal.writeAttribute('process.swing_width', 3.5);
    expect(fake.writes.last.$2, [35]);
  });

  test('writeAttribute bit does RMW on holding word', () async {
    final config = _writeConfig();
    final fake = FakeWriteTransport(config.transport);
    fake.holdingByStart[0x0058] = [0x0010]; // bit4 already set
    final hal = ModbusHal.fromConfig(config, transport: fake);

    await hal.writeAttribute('control.laser_enable', true);
    expect(fake.writes.last.$2.single & 0x0001, 0x0001);
    expect(fake.writes.last.$2.single & 0x0010, 0x0010);

    await hal.writeAttribute('control.laser_enable', false);
    expect(fake.writes.last.$2.single & 0x0001, 0);
    expect(fake.writes.last.$2.single & 0x0010, 0x0010);
  });

  test('writeGroup encodes multiple process attrs into contiguous FC16', () async {
    final config = _writeConfig();
    final fake = FakeWriteTransport(config.transport);
    fake.holdingByStart[0x0060] = List<int>.filled(8, 0);
    final hal = ModbusHal.fromConfig(config, transport: fake);

    await hal.writeGroup('process', {
      'process.laser_power': 40,
      'process.swing_width': 2.0,
    });
    expect(fake.writeMultipleCalls, 1);
    final written = fake.writes.last;
    expect(written.$1, 0x0060);
    expect(written.$2.length, 8);
    expect(written.$2[0], 4000); // 0x0060 laser power 40% → ×100
    expect(written.$2[7], 20); // 0x0067 → offset 7
  });

  test('writeAttribute u16_array writes contiguous words', () async {
    final config = _writeConfig();
    final fake = FakeWriteTransport(config.transport);
    final hal = ModbusHal.fromConfig(config, transport: fake);

    await hal.writeAttribute('upgrade.data', [1, 2, 3, 4]);
    expect(fake.writes.last.$1, 0x0050);
    expect(fake.writes.last.$2, [1, 2, 3, 4]);
  });

  test('writeAttribute fails when no write capability', () async {
    final config = _writeConfig(writeSingle: false, writeMultiple: false);
    final fake = FakeWriteTransport(config.transport);
    final hal = ModbusHal.fromConfig(config, transport: fake);

    await expectLater(
      hal.writeAttribute('process.laser_power', 1),
      throwsA(isA<HalUnsupportedException>()),
    );
  });
}
