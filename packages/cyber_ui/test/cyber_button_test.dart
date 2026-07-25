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
    final deco = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = deco.decoration as BoxDecoration;
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

    final decos = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration! as BoxDecoration)
        .toList();
    expect(decos.length, greaterThanOrEqualTo(2));
    expect(decos[0].gradient?.colors, decos[1].gradient?.colors);
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

  testWidgets('rounded shape uses pill corner radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberButton(
            shape: CyberButtonShape.rounded,
            height: 58,
            onPressed: _noop,
            child: const Text('Pill'),
          ),
        ),
      ),
    );
    final deco = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = deco.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(29));
  });

  testWidgets('default layout is intrinsic width (not full-bleed)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CyberButton(
                    onPressed: _noop,
                    child: const Text('Connect to Hidden Network'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(CyberButton));
    expect(size.width, lessThan(800));
    expect(size.width, greaterThan(100));
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
