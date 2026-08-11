import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/mpp_video_route_gate.dart';

void main() {
  setUp(MppVideoRouteGate.debugReset);
  tearDown(MppVideoRouteGate.debugReset);

  test('cover extract waits while decoder lease is held', () async {
    final order = <String>[];

    await MppVideoRouteGate.beforeAcquire();
    order.add('acquired');

    final extract = MppVideoRouteGate.runExclusive(() async {
      order.add('extract');
      return 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(order, ['acquired']);

    MppVideoRouteGate.scheduleRelease(() async {
      order.add('released');
    });

    expect(await extract, 1);
    expect(order, ['acquired', 'released', 'extract']);
  });

  test('AI extract can run while decoder lease is held', () async {
    final order = <String>[];

    await MppVideoRouteGate.beforeAcquire();
    order.add('acquired');

    await MppVideoRouteGate.runExclusive(() async {
      order.add('ai-extract');
      return null;
    }, waitForDecoder: false);

    expect(order, ['acquired', 'ai-extract']);

    MppVideoRouteGate.scheduleRelease(() async {
      order.add('released');
    });
    await Future<void>.delayed(MppVideoRouteGate.settle * 2);
    expect(order.last, 'released');
  });

  test('beforeAcquire waits for in-flight cover extract', () async {
    final order = <String>[];

    final extract = MppVideoRouteGate.runExclusive(() async {
      order.add('extract-start');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      order.add('extract-end');
      return true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final acquire = MppVideoRouteGate.beforeAcquire().then((_) {
      order.add('acquired');
    });

    await extract;
    await acquire;
    expect(order, ['extract-start', 'extract-end', 'acquired']);

    MppVideoRouteGate.scheduleRelease(() async {});
    await Future<void>.delayed(MppVideoRouteGate.settle * 2);
  });

  test('beforeAcquire is re-entrant while holding', () async {
    await MppVideoRouteGate.beforeAcquire();
    await MppVideoRouteGate.beforeAcquire();
    MppVideoRouteGate.scheduleRelease(() async {});
    await Future<void>.delayed(MppVideoRouteGate.settle * 2);
  });
}
