import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OTG mode picker shows standard three-mode copy', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showCyberUsbOtgModeDialog(
                    context: context,
                    useFakeGlass: true,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Select USB Mode'), findsOneWidget);
    expect(find.text('Debug over USB'), findsOneWidget);
    expect(find.text('Media Transfer Protocol'), findsOneWidget);
    expect(find.text('Connect Gadget'), findsOneWidget);

    await tester.tap(find.text('Media Transfer Protocol'));
    await tester.pumpAndSettle();
    expect(selected, 'mtp');
  });

  testWidgets('gadget option list omits host', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showCyberUsbOtgModeDialog(
                    context: context,
                    options: CyberUsbOtgModeCopy.gadgetModes,
                    useFakeGlass: true,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Gadget'), findsNothing);
    expect(find.text('Debug over USB'), findsOneWidget);
  });
}
