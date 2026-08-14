import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_display_typography.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';

void main() {
  test('MonitorArcGeometry: 0% at start, 100% at end of 270° sweep', () {
    final a0 = MonitorArcGeometry.angleForProgress(0);
    final a1 = MonitorArcGeometry.angleForProgress(1);
    expect(a0, MonitorArcGeometry.startAngle);
    expect(a1, MonitorArcGeometry.startAngle + MonitorArcGeometry.sweepAngle);
  });

  test('integrated-ring preset runs clockwise from 140° through a 260° sweep',
      () {
    const degrees = 180 / 3.141592653589793;
    expect(GaugeArcPresets.integratedRing.startAngle * degrees,
        closeTo(140, 1e-9));
    expect(GaugeArcPresets.integratedRing.sweepAngle * degrees,
        closeTo(260, 1e-9));
    expect(
      GaugeArcPresets.integratedRing.angleForProgress(1) * degrees,
      closeTo(400, 1e-9),
    );
    expect(
      GaugeArcPresets.integratedRing.sweepAngle +
          GaugeArcPresets.integratedRing.complementSweepAngle,
      closeTo(2 * 3.141592653589793, 1e-9),
    );
  });

  test('flat annular sector has concentric arcs and radial terminal cuts', () {
    const center = Offset(100, 100);
    const innerRadius = 40.0;
    const outerRadius = 60.0;
    const startAngle = 0.0;
    const sweepAngle = math.pi / 2;
    final path = MonitorArcGeometry.flatAnnularSector(
      center: center,
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );

    Offset radialPoint(double radius, double angle) =>
        MonitorArcGeometry.pointOnArc(center, radius, angle);

    // Constant 20px thickness throughout the live sector.
    expect(path.contains(radialPoint(39, math.pi / 4)), isFalse);
    expect(path.contains(radialPoint(41, math.pi / 4)), isTrue);
    expect(path.contains(radialPoint(59, math.pi / 4)), isTrue);
    expect(path.contains(radialPoint(61, math.pi / 4)), isFalse);

    // A rounded cap would include both of these mid-ring points because they
    // sit less than capRadius (10px) beyond the requested terminal angles.
    expect(path.contains(radialPoint(50, -0.1)), isFalse);
    expect(path.contains(radialPoint(50, sweepAngle + 0.1)), isFalse);

    // Perimeter = outer arc + end radial + inner arc + start radial.
    final expectedLength = outerRadius * sweepAngle +
        (outerRadius - innerRadius) +
        innerRadius * sweepAngle +
        (outerRadius - innerRadius);
    final metric = path.computeMetrics().single;
    // Skia flattens circular path metrics numerically; keep the tolerance
    // below one logical pixel while still detecting semicircular cap length.
    expect(metric.length, closeTo(expectedLength, 0.5));
  });

  test('integrated ring cabin clears scale terminals and lifts its concavity',
      () {
    final geometry = IntegratedRingGaugeGeometry.compute(side: 260);

    expect(
        geometry.outerRimBounds.center, geometry.ringSectorOuterBounds.center);
    expect(geometry.bottomCabinOuterBounds, geometry.outerRimBounds);
    expect(geometry.outerRimBounds.center, geometry.center);
    expect(geometry.outerRimRadiusDelta, closeTo(260 * 0.035, 1e-9));
    expect(geometry.majorTickOuterRadius, geometry.outerRimRadius);
    expect(geometry.majorTickInnerRadius, geometry.ringSectorOuterRadius);
    expect(
        geometry.majorTickInnerRadius, lessThan(geometry.majorTickOuterRadius));
    expect(geometry.labelBandRadius, lessThan(geometry.majorTickInnerRadius));
    expect(geometry.labelBandRadius, greaterThan(geometry.ringInnerRadius));
    expect(
      IntegratedRingGaugeGeometry.bottomCabinTerminalClearance *
          180 /
          3.141592653589793,
      closeTo(16, 1e-9),
    );
    expect(
      geometry.bottomCabinSweepAngle * 180 / math.pi,
      closeTo(68, 1e-9),
    );
    expect(
      geometry.ringSectorOuterRadius,
      greaterThan(geometry.bottomCabinInnerRadius),
    );
    expect(
      geometry.bottomCabinInnerApexY,
      lessThan(geometry.centerDialBaselineY),
    );
    expect(
      geometry.bottomCabinInnerLiftAboveDialBaseline,
      closeTo(260 * 0.045, 1e-9),
    );
  });

  test('bottom cabin uses a short plain sector with radial side walls', () {
    final geometry = IntegratedRingGaugeGeometry.compute(side: 260);
    final path = geometry.bottomCabinPath();
    final innerRight = MonitorArcGeometry.pointOnArc(
      geometry.center,
      geometry.bottomCabinInnerRadius,
      geometry.bottomCabinRightAngle,
    );
    final outerRight = MonitorArcGeometry.pointOnArc(
      geometry.center,
      geometry.outerRimRadius,
      geometry.bottomCabinRightAngle,
    );
    final innerLeft = MonitorArcGeometry.pointOnArc(
      geometry.center,
      geometry.bottomCabinInnerRadius,
      geometry.bottomCabinLeftAngle,
    );
    final outerLeft = MonitorArcGeometry.pointOnArc(
      geometry.center,
      geometry.outerRimRadius,
      geometry.bottomCabinLeftAngle,
    );

    // Both side walls are radial: inner and outer endpoints share one ray.
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    expect(
      cross(innerRight - geometry.center, outerRight - geometry.center),
      closeTo(0, 1e-9),
    );
    expect(
      cross(innerLeft - geometry.center, outerLeft - geometry.center),
      closeTo(0, 1e-9),
    );
    expect(innerLeft.dx, closeTo(2 * geometry.center.dx - innerRight.dx, 1e-9));
    expect(outerLeft.dx, closeTo(2 * geometry.center.dx - outerRight.dx, 1e-9));
    expect(innerLeft.dy, closeTo(innerRight.dy, 1e-9));
    expect(outerLeft.dy, closeTo(outerRight.dy, 1e-9));

    final side = geometry.center.dx * 2;
    expect((outerRight.dx - outerLeft.dx) / side, lessThan(0.55));
    final midRadius =
        (geometry.outerRimRadius + geometry.bottomCabinInnerRadius) / 2;
    final cabinMid = MonitorArcGeometry.pointOnArc(
      geometry.center,
      midRadius,
      math.pi / 2,
    );
    expect(path.contains(cabinMid), isTrue);

    // Halfway through the new 16° clearance remains outside the cabin.
    final terminalClearanceProbe = MonitorArcGeometry.pointOnArc(
      geometry.center,
      midRadius,
      geometry.bottomCabinScaleRightAngle +
          IntegratedRingGaugeGeometry.bottomCabinTerminalClearance / 2,
    );
    expect(path.contains(terminalClearanceProbe), isFalse);

    // Perimeter proves the path contains two circular arcs and two straight
    // radial walls, with no cubic/conic corner occupation.
    final expectedLength =
        (geometry.outerRimRadius + geometry.bottomCabinInnerRadius) *
                geometry.bottomCabinSweepAngle +
            2 * (geometry.outerRimRadius - geometry.bottomCabinInnerRadius);
    expect(
      path.computeMetrics().single.length,
      closeTo(expectedLength, 0.5),
    );
  });

  test('majorValues: 11 labeled majors for max/10 (no minors)', () {
    final marks = CurrentArcGaugeGeom.majorValues(
      min: 0,
      max: 100,
      majorTickEvery: 0,
    );
    expect(marks.length, 11);
    expect(marks.first, 0);
    expect(marks.last, 100);
    expect(marks[1], 10);

    final kpa = CurrentArcGaugeGeom.majorValues(
      min: 0,
      max: 1500,
      majorTickEvery: 150,
    );
    expect(kpa.length, 11);
    expect(kpa, [0, 150, 300, 450, 600, 750, 900, 1050, 1200, 1350, 1500]);

    expect(
      CurrentArcGaugeGeom.evenlySpacedProgresses(7),
      [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1],
    );
    expect(
      CurrentArcGaugeGeom.intermediateProgresses([0, .5, 1], 1),
      [.25, .75],
    );
  });

  test('geometry: tick feet flush with track outer rim', () {
    const side = 200.0;
    const trackW = 22.0;
    final geom = CurrentArcGaugeGeom.compute(
      side: side,
      trackWidth: trackW,
      maxValue: 100,
      labelStyle: const TextStyle(fontSize: 18),
      radiusBoost: 0,
    );
    expect(geom.scaleInnerRadius, geom.trackOuterRimRadius);
    expect(
      geom.ringRadius + geom.trackWidth / 2,
      closeTo(geom.scaleInnerRadius, 0.01),
    );
    expect(geom.scaleOuterRadius, greaterThan(geom.scaleInnerRadius));
    expect(geom.labelBandRadius, greaterThan(geom.scaleOuterRadius));
  });

  test('geometry: radiusBoost +25 grows ring by 25 when room allows', () {
    const side = 220.0;
    const trackW = 18.0;
    final labelStyle = TextStyle(fontSize: side * (18 / 200));
    final base = CurrentArcGaugeGeom.compute(
      side: side,
      trackWidth: trackW,
      maxValue: 1500,
      labelStyle: labelStyle,
      radiusBoost: 0,
    );
    final boosted = CurrentArcGaugeGeom.compute(
      side: side,
      trackWidth: trackW,
      maxValue: 1500,
      labelStyle: labelStyle,
      radiusBoost: 25,
    );
    expect(boosted.ringRadius - base.ringRadius, closeTo(25, 0.01));
    expect(
      boosted.trackOuterRimRadius - base.trackOuterRimRadius,
      closeTo(25, 0.01),
    );
  });

  test('geometry: opticalVerticalOffset shifts open-bottom arc downward', () {
    const side = 234.0;
    final labelStyle = TextStyle(fontSize: side * (18 / 200), height: 1.0);
    final geom = CurrentArcGaugeGeom.compute(
      side: side,
      trackWidth: 18,
      maxValue: 1500,
      labelStyle: labelStyle,
    );
    final probe = TextPainter(
      text: TextSpan(text: '1500', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = geom.opticalVerticalOffset(labelHalfHeight: probe.height / 2);
    // Horseshoe content sits high in the square → offset must be positive.
    expect(dy, greaterThan(8));
    expect(dy, lessThan(side * 0.15));
  });

  testWidgets('CurrentArcGauge paints majors as Text widgets, not minors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CurrentArcGauge(
              value: 40,
              min: 0,
              max: 100,
              majorTickEvery: 10,
              size: 200,
              trackWidth: 16,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0'), findsWidgets);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    // Minor 5 would appear only if subdiv ticks were labeled.
    expect(find.text('5'), findsNothing);
  });

  testWidgets('CurrentArcGauge renders only evenly spaced selected ticks',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CurrentArcGauge(
              value: 256,
              min: 0,
              max: 1500,
              evenlySpacedTickValues: [0, 300, 600, 750, 900, 1200, 1500],
              size: 220,
              trackWidth: 16,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final label in ['0', '300', '600', '750', '900', '1200', '1500']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in ['150', '450', '1050', '1350']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('integrated ring separates value, unit, and bottom-cabin name',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CurrentArcGauge(
              visualStyle: GaugeVisualStyle.integratedRing,
              value: 42,
              min: 0,
              max: 100,
              majorTickEvery: 10,
              unit: 'A',
              title: 'Laser Current',
              size: 240,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Laser\nCurrent'), findsOneWidget);
    expect(find.text('Laser'), findsNothing);
    expect(find.text('Current'), findsNothing);

    final nameText = tester.widget<Text>(find.text('Laser\nCurrent'));
    expect(nameText.maxLines, 2);
    expect(nameText.overflow, TextOverflow.visible);
    expect(nameText.textAlign, TextAlign.center);

    final valueCenter = tester.getCenter(find.text('42'));
    final unitCenter = tester.getCenter(find.text('A'));
    final titleCenter = tester.getCenter(find.text('Laser\nCurrent'));
    final cabinRect = tester.getRect(
      find.byKey(const ValueKey<String>('gauge-bottom-info-cabin')),
    );
    final titleRect = tester.getRect(find.text('Laser\nCurrent'));
    expect(unitCenter.dx, closeTo(valueCenter.dx, 0.01));
    expect(unitCenter.dy, greaterThan(valueCenter.dy));
    expect(titleCenter.dy, greaterThan(unitCenter.dy));
    expect(cabinRect.height, closeTo(240 * 0.36, 0.01));
    expect(titleRect.top,
        greaterThanOrEqualTo(cabinRect.top + cabinRect.height * 0.22));
    expect(titleRect.bottom,
        lessThanOrEqualTo(cabinRect.bottom - cabinRect.height * 0.08));
  });

  testWidgets('integrated-ring gas scale renders all 11 symmetric major labels',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CurrentArcGauge(
              visualStyle: GaugeVisualStyle.integratedRing,
              value: 725,
              min: 0,
              max: 1500,
              majorTickEvery: 150,
              unit: 'kPa',
              title: 'Gas Pressure',
              size: 260,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final label in [
      '0',
      '150',
      '300',
      '450',
      '600',
      '750',
      '900',
      '1050',
      '1200',
      '1350',
      '1500',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Gas\nPressure'), findsOneWidget);
  });

  testWidgets('two-line gauge name fits the minimum integrated-ring size',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.12)),
            child: Center(
              child: CurrentArcGauge(
                visualStyle: GaugeVisualStyle.integratedRing,
                value: 0,
                max: 1500,
                majorTickEvery: 150,
                unit: 'kPa',
                title: 'Gas\nPressure',
                size: 160,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gas\nPressure'), findsOneWidget);
    final cabinRect = tester.getRect(
      find.byKey(const ValueKey<String>('gauge-bottom-info-cabin')),
    );
    final titleRect = tester.getRect(find.text('Gas\nPressure'));
    expect(titleRect.top, greaterThan(cabinRect.top));
    expect(titleRect.bottom, lessThan(cabinRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paired gauges align their arc geometry despite label width',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CurrentArcGauge(
                  value: 0,
                  max: 1500,
                  evenlySpacedTickValues: [
                    0,
                    300,
                    600,
                    750,
                    900,
                    1200,
                    1500,
                  ],
                  geometryMaxLabelValue: 100,
                  size: 220,
                  trackWidth: 16,
                ),
                CurrentArcGauge(
                  value: 0,
                  max: 100,
                  majorTickEvery: 10,
                  size: 220,
                  trackWidth: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gasRect = tester.getRect(find.byType(CurrentArcGauge).first);
    final currentRect = tester.getRect(find.byType(CurrentArcGauge).last);
    final gasTop = tester.getRect(find.text('750')).center - gasRect.topLeft;
    final currentTop =
        tester.getRect(find.text('50')).center - currentRect.topLeft;
    final gasEnd = tester.getRect(find.text('1500')).center - gasRect.topLeft;
    final currentEnd =
        tester.getRect(find.text('100')).center - currentRect.topLeft;

    expect(gasTop.dx, closeTo(currentTop.dx, 0.01));
    expect(gasTop.dy, closeTo(currentTop.dy, 0.01));
    expect(gasEnd.dx, closeTo(currentEnd.dx, 0.01));
    expect(gasEnd.dy, closeTo(currentEnd.dy, 0.01));
  });

  testWidgets('horseshoe titles reuse gaugeName at the shared geometry scale',
      (tester) async {
    const size = 234.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CurrentArcGauge(
              value: 0,
              titleLine1: 'Gas',
              titleLine2: 'Pressure',
              size: size,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final expected =
        HmiDisplayTypography.gaugeNameSize * (size / 260).clamp(0.68, 1.0);
    expect(
      tester.widget<Text>(find.text('Gas')).style?.fontSize,
      expected,
    );
    expect(
      tester.widget<Text>(find.text('Pressure')).style?.fontSize,
      expected,
    );
  });
}
