import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:test/test.dart';

final class _MemLog implements AlarmLogRepository {
  final List<AlarmLogEntry> rows = [];
  final _ctrl = StreamController<List<AlarmLogEntry>>.broadcast();

  @override
  Future<void> clear() async {
    rows.clear();
    _ctrl.add(List.unmodifiable(rows));
  }

  @override
  Future<void> insertRising(AlarmLogEntry entry) async {
    rows.insert(0, entry);
    _ctrl.add(List.unmodifiable(rows));
  }

  @override
  Future<List<AlarmLogEntry>> query({int? limit}) async {
    if (limit == null) {
      return List.unmodifiable(rows);
    }
    return rows.take(limit).toList(growable: false);
  }

  @override
  Stream<List<AlarmLogEntry>> watch({int? limit}) => _ctrl.stream;
}

final class _RecordingPresentation implements WarnPresentation {
  final shows = <String>[];
  final dismisses = <String>[];
  final updates = <String>[];

  @override
  Future<void> dismiss(String code) async {
    dismisses.add(code);
  }

  @override
  Future<void> show(WarnEpisode episode, AlarmCodeEntry entry) async {
    shows.add(episode.code);
  }

  @override
  Future<void> update(WarnEpisode episode, AlarmCodeEntry entry) async {
    updates.add(episode.code);
  }
}

final class _CtrlSource implements AlarmSignalSource {
  final _ctrl = StreamController<AlarmSignalEvent>.broadcast();

  @override
  Stream<AlarmSignalEvent> get events => _ctrl.stream;

  void emit(AlarmSignalEvent e) => _ctrl.add(e);

  Future<void> close() => _ctrl.close();
}

final class _MutableGate implements WarnGate {
  _MutableGate({required this.suppressed});

  bool suppressed;

  @override
  bool get isPresentationSuppressed => suppressed;
}

void main() {
  group('AlarmCodeCatalog', () {
    test('resolve soft-fails unknown', () {
      final cat = AlarmCodeCatalog([
        const AlarmCodeEntry(
          code: 'H001',
          severity: AlarmSeverity.high,
          title: 'Gun comm',
          body: 'Check gun head',
        ),
      ]);
      expect(cat.resolve('H001').title, 'Gun comm');
      expect(cat.resolve('Z999').severity, AlarmSeverity.unknown);
      expect(cat.missingCodes(['H001', 'Z999']), ['Z999']);
    });
  });

  group('WarnAlarmCoordinator', () {
    late AlarmCodeCatalog catalog;
    late _CtrlSource source;
    late _MemLog log;
    late _RecordingPresentation presentation;
    late WarnAlarmCoordinator coord;

    setUp(() async {
      catalog = AlarmCodeCatalog([
        const AlarmCodeEntry(
          code: 'H001',
          severity: AlarmSeverity.high,
          title: 'Gun head communication',
          body: 'Gun comm fault',
          label: 'Gun head communication',
        ),
      ]);
      source = _CtrlSource();
      log = _MemLog();
      presentation = _RecordingPresentation();
      coord = WarnAlarmCoordinator(
        catalog: catalog,
        signals: source,
        presentation: presentation,
        log: log,
        now: () => DateTime.utc(2026, 7, 21, 10),
      );
      await coord.start();
    });

    tearDown(() async {
      await coord.dispose();
      await source.close();
    });

    test('rising shows dialog and inserts history', () async {
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
          attributeId: 'alarm.gun_comm',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(log.rows, hasLength(1));
      expect(log.rows.first.code, 'H001');
      expect(presentation.shows, ['H001']);
    });

    test('reminder does not insert history', () async {
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      // Recording presentation returns immediately; keep "showing" for reminder.
      expect(presentation.shows, ['H001']);
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.reminder,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(log.rows, hasLength(1));
      // Reminder while not actively showing re-queues another show (not a log row).
      expect(presentation.shows.length, greaterThanOrEqualTo(1));
      expect(log.rows, hasLength(1));
    });

    test('gate suppresses presentation but history inserts', () async {
      await coord.dispose();
      coord = WarnAlarmCoordinator(
        catalog: catalog,
        signals: source,
        presentation: presentation,
        log: log,
        gate: const FixedWarnGate(isPresentationSuppressed: true),
        now: () => DateTime.utc(2026, 7, 21, 10),
      );
      await coord.start();
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(log.rows, hasLength(1));
      expect(presentation.shows, isEmpty);
    });

    test('gated rising then flushPresentation shows dialog', () async {
      final mutable = _MutableGate(suppressed: true);
      await coord.dispose();
      coord = WarnAlarmCoordinator(
        catalog: catalog,
        signals: source,
        presentation: presentation,
        log: log,
        gate: mutable,
        now: () => DateTime.utc(2026, 7, 21, 10),
      );
      await coord.start();
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(presentation.shows, isEmpty);
      mutable.suppressed = false;
      await coord.flushPresentation();
      await Future<void>.delayed(Duration.zero);
      expect(presentation.shows, ['H001']);
    });

    test('falling dismisses when policy allows', () async {
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await coord.onPresentationClosed('H001');
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: false,
          kind: AlarmSignalKind.falling,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(coord.episodes.containsKey('H001'), isFalse);
      expect(presentation.dismisses, contains('H001'));
    });

    test('resist policy keeps episode until operator ack', () async {
      await coord.dispose();
      coord = WarnAlarmCoordinator(
        catalog: catalog,
        signals: source,
        presentation: presentation,
        log: log,
        policyForCode: (_) => WarnEpisodePolicy.productionResist,
        now: () => DateTime.utc(2026, 7, 21, 10),
      );
      await coord.start();
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      source.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: false,
          kind: AlarmSignalKind.falling,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(coord.episodes.containsKey('H001'), isTrue);
      await coord.acknowledgeOperator('H001');
      await Future<void>.delayed(Duration.zero);
      expect(coord.episodes.containsKey('H001'), isFalse);
    });

    test('armDemoEpisode uses demo policy and rejects unknown codes', () async {
      await coord.armDemoEpisode('Z999');
      await Future<void>.delayed(Duration.zero);
      expect(coord.episodes, isEmpty);
      expect(presentation.shows, isEmpty);

      await coord.armDemoEpisode('H001');
      await Future<void>.delayed(Duration.zero);
      expect(coord.episodes['H001']?.policy.demoSimulated, isTrue);
      expect(coord.episodes['H001']?.policy.resistExternalAutoClose, isTrue);
      expect(presentation.shows, ['H001']);
      expect(log.rows, hasLength(1));
    });

    test('clearAllForDebug clears episodes without dismiss', () async {
      await coord.armDemoEpisode('H001');
      await Future<void>.delayed(Duration.zero);
      expect(presentation.shows, ['H001']);
      await coord.clearAllForDebug();
      expect(coord.episodes, isEmpty);
      expect(presentation.dismisses, isEmpty);
    });
  });
}
