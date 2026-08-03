import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/feed_hold_progress.dart';

void main() {
  testWidgets('Feed hold progress waits 200ms then fills to latch at 3s',
      (tester) async {
    late FeedHoldProgressController progress;
    await tester.pumpWidget(
      MaterialApp(
        home: _Harness(
          onReady: (c) => progress = c,
        ),
      ),
    );

    progress.onPressStart();
    await tester.pump();
    expect(progress.value, 0);
    expect(progress.showsFill, isFalse);

    // Still in pressed-only window — no fill yet.
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress.value, 0);
    expect(progress.showsFill, isFalse);

    await tester.pump(const Duration(milliseconds: 50));
    expect(progress.value, 0);

    // Mid fill (~1.4s into the 2.8s fill ⇒ ~0.5).
    await tester.pump(const Duration(milliseconds: 1400));
    expect(progress.value, closeTo(0.5, 0.05));
    expect(progress.showsFill, isTrue);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(progress.value, closeTo(1.0, 0.02));

    progress.onLatched();
    expect(progress.latched, isTrue);
    expect(progress.showsFill, isFalse);
    expect(progress.value, 1.0);

    progress.onPressEndEarly();
    await tester.pump(const Duration(milliseconds: 500));
    expect(progress.value, 1.0);
    expect(progress.latched, isTrue);
  });

  testWidgets('release before 200ms never starts fill', (tester) async {
    late FeedHoldProgressController progress;
    await tester.pumpWidget(
      MaterialApp(
        home: _Harness(
          onReady: (c) => progress = c,
        ),
      ),
    );

    progress.onPressStart();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    progress.onPressEndEarly();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(progress.value, 0);
    expect(progress.showsFill, isFalse);
  });

  testWidgets('early release reverses over the held fill duration', (tester) async {
    late FeedHoldProgressController progress;
    await tester.pumpWidget(
      MaterialApp(
        home: _Harness(
          onReady: (c) => progress = c,
        ),
      ),
    );

    progress.onPressStart();
    await tester.pump();
    await tester.pump(DeviceControlTiming.wireFeedProgressDelay);
    await tester.pump(const Duration(milliseconds: 1120));
    final peak = progress.value;
    expect(peak, closeTo(0.4, 0.08));

    progress.onPressEndEarly();
    await tester.pump();
    // Hold fill was ~1.12s of 2.8s → reverse lasts ~1.12s.
    await tester.pump(const Duration(milliseconds: 560));
    expect(progress.value, lessThan(peak));
    expect(progress.value, greaterThan(0.05));

    await tester.pump(const Duration(milliseconds: 700));
    expect(progress.value, lessThan(0.01));
    expect(progress.showsFill, isFalse);
  });

  testWidgets('reset clears latch and fill', (tester) async {
    late FeedHoldProgressController progress;
    await tester.pumpWidget(
      MaterialApp(
        home: _Harness(
          onReady: (c) => progress = c,
        ),
      ),
    );

    progress.onPressStart();
    await tester.pump();
    await tester.pump(DeviceControlTiming.wireFeedLatchDelay);
    progress.onLatched();
    progress.reset();
    expect(progress.value, 0);
    expect(progress.latched, isFalse);
    expect(progress.showsFill, isFalse);
  });

  testWidgets('continuous ripple keeps animating while mounted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 60,
            child: FeedContinuousRipple(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(FeedContinuousRipple), findsOneWidget);
  });
}

final class _Harness extends StatefulWidget {
  const _Harness({required this.onReady});

  final void Function(FeedHoldProgressController controller) onReady;

  @override
  State<_Harness> createState() => _HarnessState();
}

final class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  late final FeedHoldProgressController _progress = FeedHoldProgressController(
    vsync: this,
    onChanged: () {
      if (mounted) {
        setState(() {});
      }
    },
  );

  @override
  void initState() {
    super.initState();
    widget.onReady(_progress);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep a listener in the tree so the ticker stays scheduled.
    return AnimatedBuilder(
      animation: _progress.animation,
      builder: (context, _) => Text('${_progress.value}'),
    );
  }
}
