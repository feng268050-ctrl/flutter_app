import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake RTU transport for health-window unit tests (no serial).
class _FakeTransport extends ModbusRtuTransport {
  _FakeTransport()
      : super(
          const ModbusTransport(
            type: 'rtu',
            device: '/dev/null',
            baud: 115200,
            commandIntervalMs: 1,
          ),
        );

  final Map<int, List<int>> inputByStart = {};

  /// When non-null, each read consumes the next outcome (true = success words).
  List<bool>? scriptedSuccess;

  int scriptIndex = 0;

  @override
  Future<List<int>?> readInputRegisters(int startAddress, int count) async {
    final script = scriptedSuccess;
    if (script != null) {
      if (scriptIndex >= script.length) {
        return List<int>.filled(count, 0);
      }
      final ok = script[scriptIndex++];
      if (!ok) return null;
      return List<int>.filled(count, 0)..[2] = 42;
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

ModbusConfig _healthConfig({
  required String mode,
  int failureThreshold = 3,
  int intervalMs = 20,
}) {
  return ModbusConfig(
    version: 1,
    transport: const ModbusTransport(
      type: 'rtu',
      device: '/dev/null',
      baud: 115200,
      commandIntervalMs: 1,
    ),
    poll: ModbusPollConfig(
      intervalMs: intervalMs,
      discardIfBusy: true,
      health: ModbusHealthWindowConfig(
        failureThreshold: failureThreshold,
        mode: mode,
      ),
    ),
    groups: {
      'status': const ModbusGroupConfig(
        id: 'status',
        space: 'input',
        start: 0x0000,
        count: 4,
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
    ],
  );
}

void main() {
  test('slide_window emits aggregate unhealthy only after consecutive threshold',
      () async {
    final transport = _FakeTransport();
    final hal = ModbusHal.fromConfig(
      _healthConfig(mode: 'slide_window', failureThreshold: 3),
      transport: transport,
    );
    final health = <ModbusHealth>[];
    final sub = hal.watchHealth().listen(health.add);

    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await hal.stopPolling();

    expect(health.every((h) => h.groupId == null), isTrue);
    final rising = health.where((h) => !h.ok).toList();
    expect(rising, isNotEmpty);
    expect(rising.first.message, contains('consecutive failures'));

    await sub.cancel();
    await hal.close();
  });

  test('slide_window ignores interleaved non-consecutive failures', () async {
    final transport = _FakeTransport()
      // fail, ok, fail, ok, fail — three failures, never three consecutive.
      ..scriptedSuccess = [false, true, false, true, false, true, true];
    final hal = ModbusHal.fromConfig(
      _healthConfig(
        mode: 'slide_window',
        failureThreshold: 3,
        intervalMs: 15,
      ),
      transport: transport,
    );
    final health = <ModbusHealth>[];
    final sub = hal.watchHealth().listen(health.add);

    await hal.startPolling();
    // Wait until the scripted pattern has been consumed.
    while (transport.scriptIndex < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await hal.stopPolling();

    expect(
      health.where((h) => !h.ok),
      isEmpty,
      reason: 'interleaved failures must not trip consecutive threshold',
    );

    await sub.cancel();
    await hal.close();
  });

  test('product.ini immediate override trips on first failure', () async {
    final transport = _FakeTransport();
    final hal = ModbusHal.fromConfig(
      _healthConfig(mode: 'slide_window', failureThreshold: 3),
      transport: transport,
    );
    hal.applyHealthWindowMode('immediate');

    final health = <ModbusHealth>[];
    final sub = hal.watchHealth().listen(health.add);
    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await hal.stopPolling();

    expect(health.where((h) => !h.ok), isNotEmpty);

    await sub.cancel();
    await hal.close();
  });

  test('recovery emits ok:true when window clears', () async {
    final transport = _FakeTransport();
    final hal = ModbusHal.fromConfig(
      _healthConfig(mode: 'immediate'),
      transport: transport,
    );
    final health = <ModbusHealth>[];
    final sub = hal.watchHealth().listen(health.add);

    await hal.startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    transport.inputByStart[0x0000] = [0, 0, 42, 0];
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await hal.stopPolling();

    expect(health.any((h) => !h.ok), isTrue);
    expect(health.any((h) => h.ok), isTrue);

    await sub.cancel();
    await hal.close();
  });
}
