import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';
import 'package:lws_hmi/features/home/presentation/home_quick_action.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

void main() {
  test('display factor clamps Large below reading 1.12', () {
    expect(HmiTextScale.displayFactorForReading(1.0), 1.0);
    expect(HmiTextScale.displayFactorForReading(0.90), 0.95);
    expect(HmiTextScale.displayFactorForReading(1.12), 1.05);
    expect(
      HmiTextScale.displayFactorForReading(1.12),
      lessThan(HmiTextScale.readingLarge),
    );
  });

  test('Class B settings row and tab height track reading tiers', () {
    expect(HmiTextScale.settingsRowFactorForReading(0.90), 0.95);
    expect(HmiTextScale.settingsRowFactorForReading(1.0), 1.0);
    expect(HmiTextScale.settingsRowFactorForReading(1.12), 1.12);
    expect(HmiTextScale.tabHeightForReading(0.90), 64);
    expect(HmiTextScale.tabHeightForReading(1.0), 68);
    expect(HmiTextScale.tabHeightForReading(1.12), 76);
  });

  testWidgets('Home Quick Action captions stay at Medium under Large',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.12)),
        child: MaterialApp(
          home: Scaffold(
            body: HomeQuickAction(
              cardWidth: 108,
              cardHeight: 108,
              label: 'Settings',
              onPressed: () {},
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final label = find.text('Settings');
    expect(label, findsOneWidget);
    expect(MediaQuery.textScalerOf(tester.element(label)).scale(100), 100);
  });

  test('WordBoundary packLines follows TextScaler', () {
    const style = TextStyle(fontSize: 24, fontWeight: FontWeight.w400);
    const words = ['Camera', 'Communication', 'Alarm', 'Detected'];
    const maxWidth = 220.0;

    final medium = WordBoundaryLabel.packLines(
      words: words,
      style: style,
      maxWidth: maxWidth,
      maxLines: 3,
      textScaler: TextScaler.noScaling,
    );
    final large = WordBoundaryLabel.packLines(
      words: words,
      style: style,
      maxWidth: maxWidth,
      maxLines: 3,
      textScaler: const TextScaler.linear(1.12),
    );

    // Same copy under a larger scaler cannot use fewer lines than Medium.
    expect(large.length, greaterThanOrEqualTo(medium.length));
  });

  testWidgets('WordBoundaryLabel never soft-wraps mid-word under Large',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.12)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              child: WordBoundaryLabel(
                text: 'Continuous Welding',
                style: TextStyle(fontSize: 24, height: 1.15),
                maxLines: 2,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Continuous'), findsOneWidget);
    expect(find.text('Welding'), findsOneWidget);
    // Mid-word fragments must not appear as separate Text widgets.
    expect(find.text('Weld'), findsNothing);
    expect(find.text('ing'), findsNothing);
    expect(find.text('Continuous Weld'), findsNothing);
  });

  test('homeQuickActionLabelFontSize fits Settings to the full card width', () {
    const card = 108.0;
    final fontSize = homeQuickActionLabelFontSize(card);
    final width = (TextPainter(
      text: TextSpan(
        text: kHomeQuickActionLabelSizeRef,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
        .width;

    expect(width, closeTo(card, 0.1));
  });
}
