import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/features/warn_alarm/catalog/product_alarm_catalog.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/camera_comm_alarm_adapter.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/merging_alarm_signal_source.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';

void main() {
  group('CameraCommAlarmAdapter', () {
    test('unknown ignored; unhealthy rising; healthy falling; no spam', () async {
      final adapter = CameraCommAlarmAdapter();
      final events = <AlarmSignalEvent>[];
      final sub = adapter.events.listen(events.add);
      final now = DateTime.utc(2026, 7, 22);

      adapter.debugApplyHealth(
        IpCameraHealth(phase: IpCameraHealthPhase.unknown, updatedAt: now),
      );
      expect(events, isEmpty);

      adapter.debugApplyHealth(
        IpCameraHealth(phase: IpCameraHealthPhase.healthy, updatedAt: now),
      );
      expect(events, isEmpty, reason: 'first healthy only primes');

      adapter.debugApplyHealth(
        IpCameraHealth(
          phase: IpCameraHealthPhase.unhealthy,
          detail: 'unreachable',
          updatedAt: now,
        ),
      );
      expect(events, hasLength(1));
      expect(events.single.code, LaserAlarmPolicy.alarmC002);
      expect(events.single.kind, AlarmSignalKind.rising);
      expect(events.single.active, isTrue);

      adapter.debugApplyHealth(
        IpCameraHealth(phase: IpCameraHealthPhase.unhealthy, updatedAt: now),
      );
      expect(events, hasLength(1), reason: 'no duplicate rising');

      adapter.debugApplyHealth(
        IpCameraHealth(phase: IpCameraHealthPhase.unknown, updatedAt: now),
      );
      expect(events, hasLength(1), reason: 'unknown does not clear');

      adapter.debugApplyHealth(
        IpCameraHealth(phase: IpCameraHealthPhase.healthy, updatedAt: now),
      );
      expect(events, hasLength(2));
      expect(events.last.kind, AlarmSignalKind.falling);

      await sub.cancel();
      await adapter.dispose();
    });

    test('bind listens to stub camera health Stream only', () async {
      final cam = StubIpCameraController(cameraHost: '192.168.1.100');
      final adapter = CameraCommAlarmAdapter();
      final events = <AlarmSignalEvent>[];
      final sub = adapter.events.listen(events.add);

      await adapter.bind(cam);
      expect(events, isEmpty);

      cam.setHealth(IpCameraHealthPhase.unhealthy, detail: 'down');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single.code, CameraCommAlarmAdapter.alarmCode);

      cam.setHealth(IpCameraHealthPhase.healthy);
      await Future<void>.delayed(Duration.zero);
      expect(events.last.kind, AlarmSignalKind.falling);

      await sub.cancel();
      await adapter.dispose();
      await cam.dispose();
    });
  });

  group('MergingAlarmSignalSource + coordinator C002', () {
    test('camera rising arms episode and active list; gate suppresses modal',
        () async {
      final camera = CameraCommAlarmAdapter();
      final modbus = _CtrlSource();
      final merged = MergingAlarmSignalSource([modbus, camera]);
      final log = _MemLog();
      final presentation = _RecordingPresentation();
      final gate = _MutableGate(suppressed: true);
      final catalog = ProductAlarmCatalog.seed();
      final coord = WarnAlarmCoordinator(
        catalog: catalog,
        signals: merged,
        presentation: presentation,
        log: log,
        gate: gate,
      );
      await coord.start();

      camera.debugApplyHealth(
        IpCameraHealth(
          phase: IpCameraHealthPhase.unhealthy,
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(coord.episodes[LaserAlarmPolicy.alarmC002]?.faultActive, isTrue);
      expect(log.rows, hasLength(1));
      expect(log.rows.single.code, 'C002');
      expect(presentation.shows, isEmpty, reason: 'gate suppresses modal');

      gate.suppressed = false;
      await coord.flushPresentation();
      expect(presentation.shows, ['C002']);

      // Modbus path still flows through merge.
      modbus.emit(
        const AlarmSignalEvent(
          code: 'H001',
          active: true,
          kind: AlarmSignalKind.rising,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(coord.episodes['H001']?.faultActive, isTrue);

      camera.debugApplyHealth(
        IpCameraHealth(
          phase: IpCameraHealthPhase.healthy,
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        coord.episodes['C002']?.faultActive ?? false,
        isFalse,
        reason: 'falling clears fault (episode may be torn down)',
      );

      await coord.dispose();
      await merged.dispose();
      await camera.dispose();
      await modbus.close();
    });
  });

  group('INFO-styled SFX policy', () {
    test('camera allow ON → INFO → no SFX code; OFF → WARN eligible', () {
      const snapOn = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: false,
        allowWorkAfterCameraAlarm: true,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: false,
      );
      const snapOff = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: false,
        allowWorkAfterCameraAlarm: false,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: false,
      );
      final episode = WarnEpisode(
        code: 'C002',
        policy: WarnEpisodePolicy.productionPassive,
      );
      final episodes = {'C002': episode};

      expect(
        WarnAlarmController.warnSoundAlertingCodes(
          episodes,
          isInfoStyle: (code) => LaserAlarmPolicy.treatBypassableAsInfo(
            code: code,
            snapshot: snapOn,
          ),
        ),
        isEmpty,
      );
      expect(
        WarnAlarmController.warnSoundAlertingCodes(
          episodes,
          isInfoStyle: (code) => LaserAlarmPolicy.treatBypassableAsInfo(
            code: code,
            snapshot: snapOff,
          ),
        ),
        ['C002'],
      );
    });

    test('sound helper only applies when a dialog is showing', () async {
      // Policy may mark C002 as WARN-eligible, but without showingCode the
      // controller must not start SFX (see _syncWarnSound).
      final audio = _FakeAudio();
      final sfx = WarnAlarmSound(audio);
      expect(sfx.isActive, isFalse);
      // Simulate "dialog showing + WARN eligible" path only.
      await sfx.ensurePlaying('C002');
      expect(sfx.isActive, isTrue);
      await sfx.stop();
      expect(sfx.isActive, isFalse);
      await sfx.dispose();
    });
  });
}

final class _FakeAudio implements MediaAudioController {
  final loopCalls = <String>[];
  bool _looping = false;

  @override
  bool get isPlaying => false;

  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Future<void> playAsset(String assetKey) async {}

  @override
  Future<void> playLoopingAsset(String assetKey) async {
    loopCalls.add(assetKey);
    _looping = true;
  }

  @override
  bool get hasActiveLoop => _looping;

  @override
  Future<void> playOneShotAsset(String assetKey) async {}

  @override
  Future<void> warmClickSession() async {}

  @override
  Future<void> stop() async {
    _looping = false;
  }

  @override
  Future<void> setVolumePercent(int percent) async {}

  @override
  Future<int> getVolumePercent() async => 80;

  @override
  Future<void> dispose() async {}
}

final class _CtrlSource implements AlarmSignalSource {
  final _ctrl = StreamController<AlarmSignalEvent>.broadcast(sync: true);

  @override
  Stream<AlarmSignalEvent> get events => _ctrl.stream;

  void emit(AlarmSignalEvent e) => _ctrl.add(e);

  Future<void> close() => _ctrl.close();
}

final class _MemLog implements AlarmLogRepository {
  final List<AlarmLogEntry> rows = [];

  @override
  Future<void> clear() async => rows.clear();

  @override
  Future<void> insertRising(AlarmLogEntry entry) async {
    rows.insert(0, entry);
  }

  @override
  Future<List<AlarmLogEntry>> query({int? limit}) async =>
      List.unmodifiable(rows);

  @override
  Stream<List<AlarmLogEntry>> watch({int? limit}) => const Stream.empty();
}

final class _RecordingPresentation implements WarnPresentation {
  final shows = <String>[];

  @override
  Future<void> dismiss(String code) async {}

  @override
  Future<void> show(WarnEpisode episode, AlarmCodeEntry entry) async {
    shows.add(episode.code);
  }

  @override
  Future<void> update(WarnEpisode episode, AlarmCodeEntry entry) async {}
}

final class _MutableGate implements WarnGate {
  _MutableGate({required this.suppressed});

  bool suppressed;

  @override
  bool get isPresentationSuppressed => suppressed;
}
