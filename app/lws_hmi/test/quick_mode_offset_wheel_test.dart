import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';

final class _CountingClick implements CyberClickSound {
  int calls = 0;

  @override
  Future<void> playClick() async {
    calls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CyberClickSoundRegistry.register(null);
  });

  testWidgets('fixed accent stays put while scroll index changes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 340,
              child: QuickModeOffsetWheel(
                itemCount: 5,
                selectedIndex: selected,
                itemExtent: 68,
                onChanged: (index) => selected = index,
                fixedAccent: const SizedBox(
                  key: ValueKey('test-accent'),
                  width: 140,
                  height: 68,
                  child: ColoredBox(color: Colors.orange),
                ),
                itemBuilder: (context, index, distance) {
                  return Center(child: Text('v$index'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final before = tester.getCenter(find.byKey(const ValueKey('test-accent')));
    await tester.drag(find.text('v0'), const Offset(0, -68));
    await tester.pumpAndSettle();
    final after = tester.getCenter(find.byKey(const ValueKey('test-accent')));

    expect(selected, 1);
    expect(after.dy, closeTo(before.dy, 0.5));
    expect(after.dx, closeTo(before.dx, 0.5));
  });

  testWidgets('tap animates to tapped item', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 400,
              child: QuickModeOffsetWheel(
                itemCount: 6,
                selectedIndex: selected,
                itemExtent: 68,
                onChanged: (index) => selected = index,
                itemBuilder: (context, index, distance) {
                  return Center(child: Text('item-$index'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('item-2', skipOffstage: false));
    // onChanged must fire on tap (finger up), not after the settle animation.
    await tester.pump();
    expect(selected, 2);
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  testWidgets('drag plays click once on release, not during press',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final clicks = _CountingClick();
    CyberClickSoundRegistry.register(clicks);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 340,
              child: QuickModeOffsetWheel(
                itemCount: 5,
                selectedIndex: selected,
                itemExtent: 68,
                onChanged: (index) => selected = index,
                itemBuilder: (context, index, distance) {
                  return Center(child: Text('s$index'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final center = tester.getCenter(find.byType(ListWheelScrollView));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(clicks.calls, 0);

    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(clicks.calls, 0);
    // Mid-drag: parent must not be notified yet (CNC enter would abort swipe).
    expect(selected, 0);

    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(clicks.calls, 0);
    expect(selected, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, greaterThan(0));
    expect(clicks.calls, 1);
  });

  testWidgets('parent rebuild mid-drag does not snap wheel back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    var selected = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 340,
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return QuickModeOffsetWheel(
                    itemCount: 6,
                    selectedIndex: selected,
                    itemExtent: 56,
                    onChanged: (index) {
                      selected = index;
                      setState(() {});
                    },
                    itemBuilder: (context, index, distance) {
                      return Center(child: Text('p$index'));
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final center = tester.getCenter(find.byType(ListWheelScrollView));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    // Simulate unrelated parent rebuild while finger is still down (old CNC bug).
    rebuild(() {});
    await tester.pump();

    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, greaterThanOrEqualTo(2));
  });

  testWidgets('tap plays click once when selection changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final clicks = _CountingClick();
    CyberClickSoundRegistry.register(clicks);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 400,
              child: QuickModeOffsetWheel(
                itemCount: 6,
                selectedIndex: selected,
                itemExtent: 68,
                onChanged: (index) => selected = index,
                itemBuilder: (context, index, distance) {
                  return Center(child: Text('t$index'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('t2', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(clicks.calls, 1);
  });

  testWidgets('disabled wheel ignores drag and tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    var selected = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 340,
              child: QuickModeOffsetWheel(
                itemCount: 5,
                selectedIndex: selected,
                itemExtent: 68,
                enabled: false,
                onChanged: (index) => selected = index,
                itemBuilder: (context, index, distance) {
                  return Center(child: Text('d$index'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.text('d1'),
      const Offset(0, -68),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(selected, 1);

    await tester.tap(
      find.text('d3', skipOffstage: false),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(selected, 1);
  });
}
