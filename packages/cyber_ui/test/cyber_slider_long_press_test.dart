import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long-press arm required before value changes', (tester) async {
    var value = 50.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return CyberSlider(
                    value: value,
                    min: 0,
                    max: 100,
                    onChanged: (v) => setState(() => value = v),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final slider = find.byType(CyberSlider);
    final center = tester.getCenter(slider);

    // Quick drag without long-press must not change value.
    final quick = await tester.startGesture(center);
    await quick.moveBy(const Offset(80, 0));
    await quick.up();
    await tester.pump();
    expect(value, 50);

    // Long-press then drag updates value (expand animation must not delay arm).
    final hold = await tester.startGesture(center);
    await tester.pump(
      const Duration(milliseconds: CyberSliderLogic.longPressThresholdMs),
    );
    await tester.pump();
    await hold.moveBy(const Offset(80, 0));
    await tester.pump();
    await hold.up();
    await tester.pump();
    expect(value, greaterThan(50));
  });

  testWidgets('track tap does not arm slider', (tester) async {
    var value = 50.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return CyberSlider(
                    value: value,
                    min: 0,
                    max: 100,
                    onChanged: (v) => setState(() => value = v),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(CyberSlider));
    // Far left of track, away from centered thumb.
    final trackLeft = Offset(box.left + 8, box.center.dy);
    final g = await tester.startGesture(trackLeft);
    await tester.pump(
      const Duration(milliseconds: CyberSliderLogic.longPressThresholdMs + 50),
    );
    await g.moveBy(const Offset(100, 0));
    await g.up();
    await tester.pump();
    expect(value, 50);
  });

  testWidgets('discrete tap selects and commits the nearest tick',
      (tester) async {
    var value = 0.0;
    var committed = double.nan;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return CyberSlider(
                    value: value,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    showTickMarks: true,
                    tapToSelect: true,
                    onChanged: (v) => setState(() => value = v),
                    onChangeEnd: (v) => committed = v,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(CyberSlider));
    await tester.tapAt(Offset(box.right - 24, box.center.dy));
    await tester.pump();

    expect(value, 2);
    expect(committed, 2);
  });

  testWidgets('drag value bubble appears while thumb is expanded',
      (tester) async {
    var value = 50.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return CyberSlider(
                    value: value,
                    min: 0,
                    max: 100,
                    showDragValueLabel: true,
                    onChanged: (v) => setState(() => value = v),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('50'), findsNothing);

    final hold =
        await tester.startGesture(tester.getCenter(find.byType(CyberSlider)));
    await tester.pump(
      const Duration(milliseconds: CyberSliderLogic.longPressThresholdMs),
    );
    await tester.pump();
    expect(find.text('50'), findsOneWidget);

    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('50'), findsNothing);
  });
}
