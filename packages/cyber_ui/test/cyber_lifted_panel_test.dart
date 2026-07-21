import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyberLiftedPanel translates by lift extent and resets',
      (tester) async {
    final lift = ValueNotifier<double>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberLiftedPanel(
            liftExtent: lift,
            child: const SizedBox(
              key: Key('card'),
              width: 100,
              height: 100,
            ),
          ),
        ),
      ),
    );

    final before = tester.getTopLeft(find.byKey(const Key('card')));
    lift.value = 120;
    await tester.pump();
    final lifted = tester.getTopLeft(find.byKey(const Key('card')));
    expect(lifted.dy, before.dy - 120);

    lift.value = 0;
    await tester.pump();
    final after = tester.getTopLeft(find.byKey(const Key('card')));
    expect(after.dy, before.dy);
    lift.dispose();
  });
}
