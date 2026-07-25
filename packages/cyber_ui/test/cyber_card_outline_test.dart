import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyberCard builds with frostGradient outline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberCard(
            child: SizedBox(width: 120, height: 80, child: Text('card')),
          ),
        ),
      ),
    );
    expect(find.text('card'), findsOneWidget);
    expect(find.byType(CyberOutlinedPanel), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('CyberCard transparent intensity skips BackdropFilter',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberCard(
            intensity: CyberBlurIntensity.transparent,
            child: SizedBox(width: 100, height: 60, child: Text('plain')),
          ),
        ),
      ),
    );
    expect(find.text('plain'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('CyberOutlinedPanel uniform uses Card side', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberOutlinedPanel(
            outline: CyberPanelOutline(
              style: CyberPanelOutlineStyle.uniform,
            ),
            color: Color(0x11000000),
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.side.width, greaterThan(0));
  });

  test('settingsCardAt cycles distinct gradient centers', () {
    expect(
      CyberBorderGradientCenter.settingsCardAt(0),
      CyberBorderGradientCenter.topBottom,
    );
    expect(
      CyberBorderGradientCenter.settingsCardAt(1),
      CyberBorderGradientCenter.topLeftBottomRight,
    );
    expect(
      CyberBorderGradientCenter.settingsCardAt(2),
      CyberBorderGradientCenter.bottomLeftTopRight,
    );
    expect(
      CyberBorderGradientCenter.settingsCardAt(0),
      isNot(CyberBorderGradientCenter.settingsCardAt(1)),
    );
  });

  testWidgets('CyberCard honors borderGradientCenter on outline painter',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberCard(
            borderGradientCenter: CyberBorderGradientCenter.topBottom,
            child: SizedBox(width: 100, height: 60, child: Text('axis')),
          ),
        ),
      ),
    );
    expect(find.text('axis'), findsOneWidget);
    final card = tester.widget<CyberCard>(find.byType(CyberCard));
    expect(card.borderGradientCenter, CyberBorderGradientCenter.topBottom);
  });

  testWidgets('axis and diagonal frost outlines paint without error',
      (tester) async {
    // Visual gold is on-device; this guards painter paths for both modes.
    for (final center in <CyberBorderGradientCenter>[
      CyberBorderGradientCenter.topBottom,
      CyberBorderGradientCenter.leftRight,
      CyberBorderGradientCenter.topLeftBottomRight,
      CyberBorderGradientCenter.bottomLeftTopRight,
      CyberBorderGradientCenter.topRightBottomLeft,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CyberOutlinedPanel(
              outline: CyberPanelOutline(gradientCenter: center),
              color: const Color(0x11000000),
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  test('axisAlignments and diagonal corners match Frost geometry', () {
    expect(
      CyberBorderGradientCenter.topBottom.axisAlignments,
      isNotNull,
    );
    expect(
      CyberBorderGradientCenter.topLeftBottomRight.diagonalCornerAlignments,
      [Alignment.topLeft, Alignment.bottomRight],
    );
    expect(
      CyberBorderGradientCenter.bottomLeftTopRight.diagonalCornerAlignments,
      CyberBorderGradientCenter.topRightBottomLeft.diagonalCornerAlignments,
    );
    expect(CyberBorderGradientCenter.topBottom.isAxis, isTrue);
    expect(CyberBorderGradientCenter.topLeftBottomRight.isDiagonal, isTrue);
  });

  test('diagonal corner radial uses short-side fraction 0.5', () {
    expect(CyberFrostPanelOutlinePainter.cornerHighlightFraction, 0.5);
  });
}
