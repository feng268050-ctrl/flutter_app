import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/home_webp_coverage_gate.dart';

void main() {
  late HomeWebpCoverageGate gate;

  setUp(() {
    gate = HomeWebpCoverageGate();
  });

  Future<void> pumpFrames(WidgetTester tester) async {
    // Avoid pumpAndSettle — dialog routes can leave tickers that never idle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('opaque page above home ⇒ pause; dialog only ⇒ not pause',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    late Route<void> homeRoute;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [gate],
        home: Builder(
          builder: (context) {
            homeRoute = ModalRoute.of(context)!;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    await pumpFrames(tester);
    gate.attachHome(homeRoute);
    expect(gate.pauseWebp, isFalse);

    final nav = navKey.currentState!;
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('settings')),
        ),
      ),
    );
    await pumpFrames(tester);
    expect(gate.pauseWebp, isTrue);

    nav.pop();
    await pumpFrames(tester);
    expect(gate.pauseWebp, isFalse);

    unawaited(
      nav.push<void>(
        RawDialogRoute<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            return const Center(child: Text('tip'));
          },
          barrierDismissible: true,
          barrierLabel: 'dismiss',
          barrierColor: const Color(0x80000000),
        ),
      ),
    );
    await pumpFrames(tester);
    expect(gate.pauseWebp, isFalse);

    nav.pop();
    await pumpFrames(tester);
  });

  testWidgets('dialog on top of opaque page still pauses (home buried)',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    late Route<void> homeRoute;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [gate],
        home: Builder(
          builder: (context) {
            homeRoute = ModalRoute.of(context)!;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    await pumpFrames(tester);
    gate.attachHome(homeRoute);

    final nav = navKey.currentState!;
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('settings')),
        ),
      ),
    );
    await pumpFrames(tester);
    expect(gate.pauseWebp, isTrue);

    unawaited(
      nav.push<void>(
        RawDialogRoute<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            return const Center(child: Text('on-settings'));
          },
          barrierDismissible: true,
          barrierLabel: 'dismiss',
          barrierColor: const Color(0x80000000),
        ),
      ),
    );
    await pumpFrames(tester);
    expect(gate.pauseWebp, isTrue);
  });
}
