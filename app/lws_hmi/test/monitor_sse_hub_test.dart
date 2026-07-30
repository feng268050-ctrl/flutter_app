import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/local_http/monitor_alerts_sse_hub.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_snapshot.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_sse_hub.dart';

void main() {
  group('MonitorStatSseHub', () {
    late MonitorStatSseHub hub;

    setUp(() {
      hub = MonitorStatSseHub(
        snapshotSupplier: () => const MonitorStatSnapshot(
          deviceStatus: {'cameraStatus': 1, 'deviceType': 1},
          deviceData: {'laserCurrent': 10},
          processParameters: null,
        ),
        heartbeatInterval: const Duration(hours: 1),
      );
    });

    tearDown(() => hub.resetForTest());

    test('encodeEvent framing', () {
      expect(
        MonitorStatSseHub.encodeEvent('stat', '{"ok":true}'),
        'event: stat\ndata: {"ok":true}\n\n',
      );
    });

    test('acquire emits immediate stat with null processParameters', () async {
      final sub = hub.acquire();
      final text = await _nextEventText(sub.frames, 'stat');
      final data = jsonDecode(text) as Map<String, Object?>;
      expect(data.containsKey('deviceStatus'), isTrue);
      expect(data.containsKey('deviceData'), isTrue);
      expect(data.containsKey('processParameters'), isTrue);
      expect(data['processParameters'], isNull);
      expect((data['deviceData'] as Map)['laserCurrent'], 10);
      sub.closeFromClient();
    });

    test('publishStat emits only on change', () async {
      final sub = hub.acquire();
      final events = <String>[];
      final done = Completer<void>();
      final listen = sub.frames.listen((chunk) {
        events.add(utf8.decode(chunk));
        if (events.where((e) => e.contains('event: stat')).length >= 2) {
          if (!done.isCompleted) {
            done.complete();
          }
        }
      });

      await Future<void>.delayed(Duration.zero);
      hub.publishStat(
        const MonitorStatSnapshot(
          deviceStatus: {'cameraStatus': 1, 'deviceType': 1},
          deviceData: {'laserCurrent': 10},
          processParameters: null,
        ),
      );
      hub.publishStat(
        const MonitorStatSnapshot(
          deviceStatus: {'cameraStatus': 1, 'deviceType': 1},
          deviceData: {'laserCurrent': 11},
          processParameters: null,
        ),
      );
      await done.future.timeout(const Duration(seconds: 2));
      final stats = events.where((e) => e.contains('event: stat')).toList();
      expect(stats, hasLength(2));
      expect(stats.last, contains('"laserCurrent":11'));
      await listen.cancel();
      sub.closeFromClient();
    });
  });

  group('MonitorAlertsSseHub', () {
    late MonitorAlertsSseHub hub;

    setUp(() {
      hub = MonitorAlertsSseHub(
        listSupplier: () async => [
          {'id': 1, 'code': 'C002', 'content': 'Camera'},
        ],
        heartbeatInterval: const Duration(hours: 1),
      );
    });

    tearDown(() => hub.resetForTest());

    test('acquire emits list array', () async {
      final sub = await hub.acquire();
      final text = await _nextEventText(sub.frames, 'list');
      final data = jsonDecode(text) as List<Object?>;
      expect(data, hasLength(1));
      expect((data.first as Map)['code'], 'C002');
      sub.closeFromClient();
    });

    test('publishNew requires id; clear emits empty object', () async {
      final sub = await hub.acquire();
      final events = <String>[];
      final done = Completer<void>();
      final listen = sub.frames.listen((chunk) {
        events.add(utf8.decode(chunk));
        final hasNew = events.any((e) => e.contains('event: new'));
        final hasClear = events.any((e) => e.contains('event: clear'));
        if (hasNew && hasClear && !done.isCompleted) {
          done.complete();
        }
      });

      await Future<void>.delayed(Duration.zero);
      hub.publishNew({'code': 'A001', 'content': 'x'});
      hub.publishNew({'id': 2, 'code': 'A001', 'content': 'One'});
      hub.publishClear();
      await done.future.timeout(const Duration(seconds: 2));

      expect(events.where((e) => e.contains('event: new')), hasLength(1));
      expect(events.any((e) => e.contains('"id":2')), isTrue);
      expect(events.any((e) => e.contains('event: clear\ndata: {}')), isTrue);
      await listen.cancel();
      sub.closeFromClient();
    });
  });
}

Future<String> _nextEventText(
  Stream<List<int>> frames,
  String eventName,
) async {
  final marker = 'event: $eventName';
  final buf = StringBuffer();
  await for (final chunk in frames.timeout(const Duration(seconds: 2))) {
    buf.write(utf8.decode(chunk));
    final text = buf.toString();
    final idx = text.indexOf(marker);
    if (idx < 0) {
      continue;
    }
    final dataIdx = text.indexOf('data: ', idx);
    if (dataIdx < 0) {
      continue;
    }
    final lineEnd = text.indexOf('\n', dataIdx);
    if (lineEnd < 0) {
      continue;
    }
    return text.substring(dataIdx + 6, lineEnd).trim();
  }
  fail('no $eventName event');
}
