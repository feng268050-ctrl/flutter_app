import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';

void main() {
  late GlobalKey<NavigatorState> navKey;
  late bool suppressed;

  Future<void> pumpApp(WidgetTester tester, GlobalPromptQueue queue) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [queue.navigatorObserver],
        home: const Scaffold(body: Text('home')),
      ),
    );
    await tester.pump();
  }

  Future<void> presentLabel(
    GlobalPromptHost host,
    String label, {
    Duration transitionDuration = const Duration(milliseconds: 200),
  }) async {
    await showGeneralDialog<void>(
      context: host.context,
      barrierDismissible: false,
      barrierLabel: label,
      transitionDuration: transitionDuration,
      pageBuilder: (ctx, a, b) {
        return AlertDialog(
          title: Text(label),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ok'),
            ),
          ],
        );
      },
    );
  }

  setUp(() {
    navKey = GlobalKey<NavigatorState>();
    suppressed = false;
  });

  testWidgets(
      'next prompt waits for previous dialog exit animation',
      (tester) async {
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester, queue);

    const exitDuration = Duration(milliseconds: 400);
    unawaited(
      queue.enqueue(
        id: 'a',
        present: (host) => presentLabel(
          host,
          'prompt-a',
          transitionDuration: exitDuration,
        ),
      ),
    );
    unawaited(
      queue.enqueue(
        id: 'b',
        present: (host) => presentLabel(host, 'prompt-b'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('prompt-a'), findsOneWidget);
    expect(find.text('prompt-b'), findsNothing);

    // Prefer dismiss over tap: WidgetTester.tap advances press-timeout time
    // that can finish a short reverse animation before assertions run.
    await queue.dismiss('a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('prompt-a'), findsOneWidget);
    expect(find.text('prompt-b'), findsNothing);

    // Exit animation (400ms) + post-completed settle gap (50ms).
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('prompt-b'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('prompt-a'), findsNothing);
    expect(find.text('prompt-b'), findsOneWidget);

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
  });

  testWidgets('FIFO order across two prompts', (tester) async {
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester, queue);

    final order = <String>[];
    final first = queue.enqueue(
      id: 'a',
      present: (host) async {
        order.add('show-a');
        await presentLabel(host, 'prompt-a');
        order.add('close-a');
      },
    );
    final second = queue.enqueue(
      id: 'b',
      present: (host) async {
        order.add('show-b');
        await presentLabel(host, 'prompt-b');
        order.add('close-b');
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('prompt-a'), findsOneWidget);
    expect(find.text('prompt-b'), findsNothing);

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(find.text('prompt-b'), findsOneWidget);

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    expect(order, ['show-a', 'close-a', 'show-b', 'close-b']);
  });

  testWidgets('dedupe same id pending replaces prior waiter', (tester) async {
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester, queue);

    var presents = 0;
    // Hold first dialog open while second id is queued behind.
    final gate = Completer<void>();
    unawaited(
      queue.enqueue(
        id: 'hold',
        present: (host) async {
          await presentLabel(host, 'hold');
          await gate.future;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final firstBind = queue.enqueue(
      id: 'deviceBind',
      present: (host) async {
        presents++;
        await presentLabel(host, 'bind-1');
      },
    );
    final secondBind = queue.enqueue(
      id: 'deviceBind',
      present: (host) async {
        presents++;
        await presentLabel(host, 'bind-2');
      },
    );

    await tester.tap(find.text('ok'));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('bind-2'), findsOneWidget);
    expect(find.text('bind-1'), findsNothing);

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    await Future.wait([firstBind, secondBind]);
    expect(presents, 1);
  });

  testWidgets('dismiss pending removes without showing', (tester) async {
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester, queue);

    final holdDone = Completer<void>();
    unawaited(
      queue.enqueue(
        id: 'hold',
        present: (host) async {
          await presentLabel(host, 'hold');
          holdDone.complete();
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final bind = queue.enqueue(
      id: 'deviceBind',
      present: (host) async {
        await presentLabel(host, 'bind');
      },
    );
    await queue.dismiss('deviceBind');
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    await bind;
    await holdDone.future;
    expect(find.text('bind'), findsNothing);
  });

  testWidgets('dismiss showing closes and pumps next', (tester) async {
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester, queue);

    unawaited(
      queue.enqueue(
        id: 'a',
        present: (host) => presentLabel(host, 'prompt-a'),
      ),
    );
    unawaited(
      queue.enqueue(
        id: 'b',
        present: (host) => presentLabel(host, 'prompt-b'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('prompt-a'), findsOneWidget);

    await queue.dismiss('a');
    await tester.pumpAndSettle();
    expect(find.text('prompt-b'), findsOneWidget);

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'dismiss after dialog self-pop does not pop the product page',
      (tester) async {
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [queue.navigatorObserver],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Text('detail-page'),
                    ),
                  ),
                );
              },
              child: const Text('open-detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail-page'), findsOneWidget);

    unawaited(
      queue.enqueue(
        id: 'warn',
        present: (host) async {
          await showGeneralDialog<void>(
            context: host.context,
            barrierDismissible: false,
            barrierLabel: 'warn',
            pageBuilder: (ctx, a, b) {
              return AlertDialog(
                title: const Text('warn-dialog'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('confirm'),
                  ),
                ],
              );
            },
          );
          // Mimic warn Confirm → onClosed → acknowledgeOperator → dismiss
          // while present() has not returned yet.
          host.markClosed();
          await queue.dismiss('warn');
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('warn-dialog'), findsOneWidget);

    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();

    expect(find.text('warn-dialog'), findsNothing);
    expect(find.text('detail-page'), findsOneWidget);
    expect(find.text('open-detail'), findsNothing);
  });

  testWidgets('self-check suppress parks then notifyGateChanged pumps',
      (tester) async {
    suppressed = true;
    final queue = GlobalPromptQueue(
      navigatorKey: navKey,
      isPumpSuppressed: () => suppressed,
    );
    await pumpApp(tester, queue);

    unawaited(
      queue.enqueue(
        id: 'a',
        present: (host) => presentLabel(host, 'prompt-a'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('prompt-a'), findsNothing);

    suppressed = false;
    queue.notifyGateChanged();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('prompt-a'), findsOneWidget);

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
  });
}
