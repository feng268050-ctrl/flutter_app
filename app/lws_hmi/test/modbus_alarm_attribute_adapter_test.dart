import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/catalog/product_alarm_catalog.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/estop_comm_alarm_mask.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

ModbusAttributeConfig _bitAttr({
  required String id,
  required String code,
  required String label,
  required String address,
}) {
  return ModbusAttributeConfig.fromJson({
    'id': id,
    'access': 'r',
    'group': 'status',
    'register': {
      'space': 'input',
      'address': address,
      'count': 1,
    },
    'decode': {'type': 'bit', 'bit': 0, 'active_high': true},
    'meta': {
      'alarm_code': code,
      'label': label,
    },
  });
}

final class _FakeModbus extends ModbusRtuClient {
  _FakeModbus() : super();

  final _ctrl = StreamController<List<ModbusAttributeChange>>.broadcast();
  final _health = StreamController<ModbusHealth>.broadcast();
  final Map<String, Object?> attributeValues = {};
  List<String>? lastWatchIds;

  @override
  Future<List<ModbusAttributeConfig>> listAttributes() async {
    return [
      _bitAttr(
        id: 'alarm.gun_comm',
        code: 'H001',
        label: 'Gun head communication',
        address: '0x0009',
      ),
      _bitAttr(
        id: EstopCommAlarmMask.laserCommAttr,
        code: 'H022',
        label: 'Laser communication',
        address: '0x000D',
      ),
      _bitAttr(
        id: EstopCommAlarmMask.wireFeederCommAttr,
        code: 'W001',
        label: 'Wire feeder communication',
        address: '0x0011',
      ),
      _bitAttr(
        id: EstopCommAlarmMask.laserEmergencyStopAttr,
        code: 'H029',
        label: 'Laser emergency stop',
        address: '0x000E',
      ),
    ];
  }

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async {
    lastWatchIds = ids?.toList();
    return _ctrl.stream;
  }

  @override
  Future<Stream<ModbusHealth>> watchHealth() async => _health.stream;

  @override
  Future<Object?> readAttribute(String id) async => attributeValues[id];

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    if (groupId != 'status') {
      return {};
    }
    return {
      EstopCommAlarmMask.laserCommAttr: attributeValues[EstopCommAlarmMask.laserCommAttr],
      EstopCommAlarmMask.wireFeederCommAttr:
          attributeValues[EstopCommAlarmMask.wireFeederCommAttr],
      EstopCommAlarmMask.laserEmergencyStopAttr:
          attributeValues[EstopCommAlarmMask.laserEmergencyStopAttr],
      EstopCommAlarmMask.emergencyStopAttr:
          attributeValues[EstopCommAlarmMask.emergencyStopAttr],
    };
  }

  void emit(List<ModbusAttributeChange> changes) {
    for (final c in changes) {
      attributeValues[c.id] = c.value;
    }
    _ctrl.add(changes);
  }
}

final class _MemLog implements AlarmLogRepository {
  final rows = <AlarmLogEntry>[];

  @override
  Future<void> insertRising(AlarmLogEntry entry) async => rows.add(entry);

  @override
  Future<void> clear() async => rows.clear();

  @override
  Future<List<AlarmLogEntry>> query({int? limit}) async =>
      List.unmodifiable(rows);

  @override
  Stream<List<AlarmLogEntry>> watch({int? limit}) => const Stream.empty();
}

final class _RecordingPresentation implements WarnPresentation {
  final shows = <String>[];

  @override
  Future<void> show(WarnEpisode episode, AlarmCodeEntry entry) async {
    shows.add(episode.code);
  }

  @override
  Future<void> update(WarnEpisode episode, AlarmCodeEntry entry) async {}

  @override
  Future<void> dismiss(String code) async {}
}

ModbusAttributeChange _change(
  String id,
  Object? value, {
  Object? previous,
  ModbusChangeKind kind = ModbusChangeKind.changed,
}) {
  return ModbusAttributeChange(
    id: id,
    value: value,
    previous: previous,
    kind: kind,
  );
}

void main() {
  test('adapter maps rising / falling / reminder without UI', () async {
    final fake = _FakeModbus();
    final adapter = ModbusAlarmAttributeAdapter(modbus: fake);
    final events = <AlarmSignalEvent>[];
    final sub = adapter.events.listen(events.add);
    await adapter.start();

    fake.emit([
      _change('alarm.gun_comm', true, previous: null, kind: ModbusChangeKind.primed),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(events.single.kind, AlarmSignalKind.rising);
    expect(events.single.code, 'H001');

    fake.emit([
      _change(
        'alarm.gun_comm',
        true,
        previous: true,
        kind: ModbusChangeKind.reminder,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(events.last.kind, AlarmSignalKind.reminder);

    fake.emit([
      _change('alarm.gun_comm', false, previous: true),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(events.last.kind, AlarmSignalKind.falling);

    await sub.cancel();
    await adapter.dispose();
  });

  test('start watches machine.emergency_stop', () async {
    final fake = _FakeModbus();
    final adapter = ModbusAlarmAttributeAdapter(modbus: fake);
    await adapter.start();
    expect(
      fake.lastWatchIds,
      contains(EstopCommAlarmMask.emergencyStopAttr),
    );
    await adapter.dispose();
  });

  group('e-stop suppresses laser/wire feeder comm', () {
    late _FakeModbus fake;
    late ModbusAlarmAttributeAdapter adapter;
    late List<AlarmSignalEvent> events;
    late List<List<ModbusAttributeChange>> monitorBatches;
    late StreamSubscription<AlarmSignalEvent> eventSub;
    late StreamSubscription<List<ModbusAttributeChange>> monitorSub;

    setUp(() async {
      fake = _FakeModbus();
      adapter = ModbusAlarmAttributeAdapter(modbus: fake);
      events = [];
      monitorBatches = [];
      eventSub = adapter.events.listen(events.add);
      monitorSub = adapter.monitorChanges.listen(monitorBatches.add);
      await adapter.start();
    });

    tearDown(() async {
      await eventSub.cancel();
      await monitorSub.cancel();
      await adapter.dispose();
    });

    test('e-stop active blocks H022/W001/H029 rising; H001 still rises',
        () async {
      fake.emit([
        _change(
          EstopCommAlarmMask.emergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      events.clear();

      fake.emit([
        _change(EstopCommAlarmMask.laserCommAttr, true, previous: false),
        _change(EstopCommAlarmMask.wireFeederCommAttr, true, previous: false),
        _change(
          EstopCommAlarmMask.laserEmergencyStopAttr,
          true,
          previous: false,
        ),
        _change('alarm.gun_comm', true, previous: false),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(events.where((e) => e.code == 'H022'), isEmpty);
      expect(events.where((e) => e.code == 'W001'), isEmpty);
      expect(events.where((e) => e.code == 'H029'), isEmpty);
      expect(events.single.code, 'H001');
      expect(events.single.kind, AlarmSignalKind.rising);
    });

    test('H029 rises only after e-stop settle while bit stays true', () async {
      final previousDelay =
          ModbusAlarmAttributeAdapter.estopMaskedResampleDelay;
      addTearDown(() {
        ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = previousDelay;
      });
      ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = Duration.zero;

      fake.emit([
        _change(
          EstopCommAlarmMask.emergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
        _change(
          EstopCommAlarmMask.laserEmergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H029'), isEmpty);

      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, false, previous: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H029'), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(events.where((e) => e.code == 'H029').single.kind,
          AlarmSignalKind.rising);
    });

    test('H022 active then e-stop → falling; release settles then re-arms if raw true',
        () async {
      final previousDelay =
          ModbusAlarmAttributeAdapter.estopMaskedResampleDelay;
      addTearDown(() {
        ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = previousDelay;
      });
      ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = Duration.zero;

      fake.emit([
        _change(
          EstopCommAlarmMask.laserCommAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.single.code, 'H022');
      expect(events.single.kind, AlarmSignalKind.rising);

      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, true, previous: false),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.last.code, 'H022');
      expect(events.last.kind, AlarmSignalKind.falling);
      expect(events.last.active, isFalse);

      final beforeRelease = events.length;
      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, false, previous: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      // Immediate release must not re-arm from cache (settle delay).
      expect(events.length, beforeRelease);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(events.length, greaterThan(beforeRelease));
      expect(events.last.code, 'H022');
      expect(events.last.kind, AlarmSignalKind.rising);
      expect(events.last.active, isTrue);
    });

    test('e-stop release does not re-arm H022 when raw clears during settle',
        () async {
      final previousDelay =
          ModbusAlarmAttributeAdapter.estopMaskedResampleDelay;
      addTearDown(() {
        ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = previousDelay;
      });
      ModbusAlarmAttributeAdapter.estopMaskedResampleDelay =
          const Duration(milliseconds: 30);

      fake.emit([
        _change(
          EstopCommAlarmMask.emergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
        _change(
          EstopCommAlarmMask.laserCommAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H022'), isEmpty);

      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, false, previous: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      // False-positive clears before settle completes.
      fake.emit([
        _change(EstopCommAlarmMask.laserCommAttr, false, previous: true),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events.where((e) => e.code == 'H022'), isEmpty);
    });

    test('settle level-read re-arms H022 when bit stays true without a change edge',
        () async {
      final previousDelay =
          ModbusAlarmAttributeAdapter.estopMaskedResampleDelay;
      addTearDown(() {
        ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = previousDelay;
      });
      ModbusAlarmAttributeAdapter.estopMaskedResampleDelay =
          const Duration(milliseconds: 20);

      // Seed raw H022=true under e-stop (warn path quiet).
      fake.emit([
        _change(
          EstopCommAlarmMask.emergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
        _change(
          EstopCommAlarmMask.laserCommAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H022'), isEmpty);

      // Release only — no further H022 watch event. Level read still sees true.
      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, false, previous: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H022'), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(events.where((e) => e.code == 'H022').single.kind,
          AlarmSignalKind.rising);
    });

    test('H029 deferred during e-stop rises after reset even if bit clears',
        () async {
      final previousDelay =
          ModbusAlarmAttributeAdapter.estopMaskedResampleDelay;
      final previousHold =
          ModbusAlarmAttributeAdapter.h029DeferredOneShotHold;
      addTearDown(() {
        ModbusAlarmAttributeAdapter.estopMaskedResampleDelay = previousDelay;
        ModbusAlarmAttributeAdapter.h029DeferredOneShotHold = previousHold;
      });
      ModbusAlarmAttributeAdapter.estopMaskedResampleDelay =
          const Duration(milliseconds: 20);
      ModbusAlarmAttributeAdapter.h029DeferredOneShotHold = Duration.zero;

      fake.emit([
        _change(
          EstopCommAlarmMask.emergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
        _change(
          EstopCommAlarmMask.laserEmergencyStopAttr,
          true,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H029'), isEmpty);

      // Bit clears on the release edge (common on reset).
      fake.attributeValues[EstopCommAlarmMask.laserEmergencyStopAttr] = false;
      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, false, previous: true),
        _change(
          EstopCommAlarmMask.laserEmergencyStopAttr,
          false,
          previous: true,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.code == 'H029'), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        events.where((e) => e.code == 'H029' && e.kind == AlarmSignalKind.rising),
        isNotEmpty,
      );
    });

    test('status checks keep raw bits under e-stop; warn path stays quiet',
        () async {
      final monitor = AlarmMonitorState();
      adapter.monitorChanges.listen(monitor.applyChanges);

      fake.emit([
        _change(EstopCommAlarmMask.emergencyStopAttr, true, previous: false),
        _change(EstopCommAlarmMask.laserCommAttr, true, previous: false),
        _change(EstopCommAlarmMask.wireFeederCommAttr, true, previous: false),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(events.where((e) => e.code == 'H022' || e.code == 'W001'), isEmpty);
      expect(monitor.laserCommFault, isTrue);
      expect(monitor.wireFeederCommFault, isTrue);

      final lastLaser = monitorBatches.last
          .where((c) => c.id == EstopCommAlarmMask.laserCommAttr)
          .last;
      expect(lastLaser.value, isTrue);
    });
  });

  test('e-stop blocks coordinator history for H022; H001 still inserts',
      () async {
    final fake = _FakeModbus();
    final adapter = ModbusAlarmAttributeAdapter(modbus: fake);
    final log = _MemLog();
    final presentation = _RecordingPresentation();
    final coord = WarnAlarmCoordinator(
      catalog: ProductAlarmCatalog.seed(),
      signals: adapter,
      presentation: presentation,
      log: log,
    );
    await adapter.start();
    await coord.start();

    fake.emit([
      _change(
        EstopCommAlarmMask.emergencyStopAttr,
        true,
        previous: null,
        kind: ModbusChangeKind.primed,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    fake.emit([
      _change(EstopCommAlarmMask.laserCommAttr, true, previous: false),
      _change(EstopCommAlarmMask.wireFeederCommAttr, true, previous: false),
      _change('alarm.gun_comm', true, previous: false),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(coord.episodes['H022']?.faultActive ?? false, isFalse);
    expect(coord.episodes['W001']?.faultActive ?? false, isFalse);
    expect(log.rows.where((r) => r.code == 'H022'), isEmpty);
    expect(log.rows.where((r) => r.code == 'W001'), isEmpty);
    expect(log.rows.where((r) => r.code == 'H001'), hasLength(1));
    expect(coord.episodes['H001']?.faultActive, isTrue);

    await coord.dispose();
    await adapter.dispose();
  });
}
