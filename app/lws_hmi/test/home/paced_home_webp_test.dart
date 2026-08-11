import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/paced_home_webp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const layers = [
    PacedHomeWebpSpec(asset: 'a.webp', fallback: 'a_static.webp'),
    PacedHomeWebpSpec(asset: 'b.webp', fallback: 'b_static.webp'),
  ];

  test('playMotion false does not start a periodic timer', () async {
    var created = 0;
    final c = PacedHomeWebpController(
      layers: layers,
      playMotion: false,
      createPeriodic: (period, onTick) {
        created++;
        return Timer(period, () {});
      },
    );
    await c.start();
    expect(created, 0);
    expect(c.isRunning, isFalse);
    c.dispose();
  });

  test('pause stops timer; resume restarts when playMotion', () async {
    final timers = <Timer>[];
    final c = PacedHomeWebpController(
      layers: layers,
      createPeriodic: (period, onTick) {
        final t = Timer(period, () {});
        timers.add(t);
        return t;
      },
    );
    c.debugAdvanceLayer = (_) async {};
    await c.start();
    expect(c.isRunning, isTrue);
    expect(timers, hasLength(1));

    c.pause();
    expect(c.isPaused, isTrue);
    expect(c.isRunning, isFalse);
    expect(timers.single.isActive, isFalse);

    c.resume();
    expect(c.isPaused, isFalse);
    expect(c.isRunning, isTrue);
    expect(timers, hasLength(2));
    c.dispose();
  });

  test('one shared tick notifies listeners once for two layers', () async {
    var advances = 0;
    final c = PacedHomeWebpController(layers: layers);
    c.debugAdvanceLayer = (_) async {
      advances++;
    };
    final before = c.notifyCount;
    await c.debugTick();
    expect(advances, 2);
    expect(c.notifyCount - before, 1);
    c.dispose();
  });

  test('overlapping ticks are coalesced via tickInFlight', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final c = PacedHomeWebpController(layers: layers);
    c.debugAdvanceLayer = (_) async {
      if (!started.isCompleted) {
        started.complete();
      }
      await release.future;
    };

    final first = c.debugTick();
    await started.future;
    final before = c.notifyCount;
    // Second tick while first is in flight must no-op.
    await c.debugTick();
    expect(c.notifyCount, before);

    release.complete();
    await first;
    expect(c.notifyCount, before + 1);
    c.dispose();
  });

  test('playMotion true after balanced pause reloads codecs', () async {
    final c = PacedHomeWebpController(layers: layers);
    c.debugAdvanceLayer = (_) async {};
    await c.start();
    final afterStart = c.notifyCount;

    c.pause();
    c.playMotion = false;
    final afterOff = c.notifyCount;
    expect(afterOff, greaterThan(afterStart));

    c.playMotion = true;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      c.notifyCount,
      greaterThan(afterOff),
      reason: 'balanced→performance must reload WebP codecs',
    );

    c.resume();
    expect(c.isRunning, isTrue);
    c.dispose();
  });

  testWidgets('playMotion false hides paced plate (no oversized static frames)',
      (tester) async {
    final c = PacedHomeWebpController(layers: layers, playMotion: false);
    await c.start();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PacedHomeWebpPlate(
                controller: c,
                layerIndex: 0,
                left: 0,
                top: 0,
                width: 100,
                height: 100,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    c.dispose();
  });
}
