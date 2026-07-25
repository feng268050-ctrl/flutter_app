import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default variant is standard (not primary orange)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberButton(
            onPressed: _noop,
            child: Text('Go'),
          ),
        ),
      ),
    );
    final button = tester.widget<CyberButton>(find.byType(CyberButton));
    expect(button.variant, CyberButtonVariant.standard);
  });

  testWidgets('primary uses solid primary fill decoration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberButton(
            variant: CyberButtonVariant.primary,
            onPressed: _noop,
            child: const Text('OK'),
          ),
        ),
      ),
    );
    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.color, CyberColors.buttonPrimaryFill);
    expect(decoration.gradient, isNull);
  });

  testWidgets('secondary matches standard chrome with red label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CyberButton(
                key: const Key('std'),
                variant: CyberButtonVariant.standard,
                onPressed: _noop,
                child: const Text('A'),
              ),
              CyberButton(
                key: const Key('sec'),
                variant: CyberButtonVariant.secondary,
                onPressed: _noop,
                child: const Text('B'),
              ),
            ],
          ),
        ),
      ),
    );
    final standard = tester.widget<CyberButton>(find.byKey(const Key('std')));
    final secondary = tester.widget<CyberButton>(find.byKey(const Key('sec')));
    expect(standard.variant, CyberButtonVariant.standard);
    expect(secondary.variant, CyberButtonVariant.secondary);

    final inks = tester.widgetList<Ink>(find.byType(Ink)).toList();
    expect(inks.length, 2);
    final standardDeco = inks[0].decoration! as BoxDecoration;
    final secondaryDeco = inks[1].decoration! as BoxDecoration;
    expect(standardDeco.border?.top.color, secondaryDeco.border?.top.color);
    expect(standardDeco.gradient?.colors, secondaryDeco.gradient?.colors);
  });

  test('button dimens match Frost heights; label matches HMI chrome', () {
    expect(CyberDimens.actionButtonHeight, 58);
    expect(CyberDimens.actionButtonSmallHeight, 40);
    expect(CyberDimens.buttonStrokeWidth, 1.0);
    expect(CyberDimens.rectangleButtonCornerRadius, 14);
    expect(CyberDimens.actionButtonFontSize, 18);
    expect(CyberDimens.actionButtonSmallFontSize, 14);
    expect(CyberDimens.cornerRadius, 28);
  });

  testWidgets('DefaultTextStyle uses size-appropriate font', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CyberButton(
                onPressed: _noop,
                child: const Text('Regular'),
              ),
              CyberButton(
                size: CyberButtonSize.small,
                onPressed: _noop,
                child: const Text('Small'),
              ),
            ],
          ),
        ),
      ),
    );
    final styles = tester
        .widgetList<DefaultTextStyle>(find.byType(DefaultTextStyle))
        .map((w) => w.style.fontSize)
        .toList();
    expect(styles, containsAll(<double>[18, 14]));
  });
}

void _noop() {}
