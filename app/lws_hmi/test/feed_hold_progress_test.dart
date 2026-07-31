import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/feed_hold_progress.dart';

void main() {
  testWidgets('Feed hold progress fills over 3s then latches without reverse',
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

    await tester.pump(const Duration(milliseconds: 1500));
    expect(progress.value, closeTo(0.5, 0.05));
    expect(progress.showsFill, isTrue);

    await tester.pump(const Duration(milliseconds: 1500));
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

  testWidgets('early release reverses over the held duration', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 1200));
    final peak = progress.value;
    expect(peak, closeTo(0.4, 0.08));

    progress.onPressEndEarly();
    await tester.pump();
    // Hold was ~1.2s → reverse lasts ~1.2s; midway should still be visible.
    await tester.pump(const Duration(milliseconds: 600));
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
