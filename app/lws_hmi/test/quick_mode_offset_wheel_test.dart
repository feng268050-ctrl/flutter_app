import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await tester.pumpAndSettle();
    expect(selected, 2);
  });
}
