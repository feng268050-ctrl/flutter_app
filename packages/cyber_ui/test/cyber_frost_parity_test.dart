import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('token defaults match frost corner radius', () {
    expect(CyberDimens.cornerRadius, 24);
    expect(CyberColors.borderHighlight.toARGB32(), 0x77FFFFFF);
    expect(CyberTone.light.blurTint, CyberBlurTint.warm);
  });

  test('CyberPanelBorder dark uses highlight border', () {
    const panel = CyberPanelBorder();
    expect(panel.flatBorderColor, CyberColors.borderHighlight);
    expect(panel.tipRimColor, CyberColors.tipRimHighlight);
    expect(panel.tipRimOutline.resolvedUniformColor, CyberColors.tipRimHighlight);
    expect(panel.width, CyberDimens.borderWidth);
    expect(panel.borderRadius.topLeft.x, CyberDimens.cornerRadius);
  });

  test('CyberPanelBorder tip rim uses 50% white highlight', () {
    const panel = CyberPanelBorder(tone: CyberTone.light);
    expect(panel.tipRimColor, const Color(0x80FFFFFF));
    expect(panel.tipRimColor.alpha, 0x80);
  });

  test('CyberClockNotes documents glyph-clip limit', () {
    expect(CyberClockNotes.glyphClipLiveBlurSupported, isFalse);
    expect(CyberClockNotes.glyphClipLiveBlurNote, isNotEmpty);
  });

  testWidgets('CyberSwitch toggles with callback', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberSwitch(
            value: value,
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('CyberNumericStepper increments', (tester) async {
    var value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberNumericStepper(
            value: value,
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(value, 6);
  });

  testWidgets('CyberOverlayHost show/dismiss', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  CyberOverlayHost.show<void>(
                    context: context,
                    useFakeGlass: true,
                    freezePageBackdrop: false,
                    builder: (ctx) => CyberPromptContent(
                      title: 'Hello',
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('CyberScaledSlider shows scale labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberScaledSlider(
            value: 0,
            min: -30,
            max: 30,
            scaleMinText: '-30',
            scaleMaxText: '30',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('-30'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(CyberSlider), findsOneWidget);
  });
}
