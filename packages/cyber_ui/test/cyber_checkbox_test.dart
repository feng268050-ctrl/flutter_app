import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyberCheckbox label tap toggles value', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CyberCheckbox(
                value: value,
                onChanged: (v) => setState(() => value = v ?? false),
                label: const Text('Caption'),
              );
            },
          ),
        ),
      ),
    );

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.text('Caption'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
