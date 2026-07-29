import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';

void main() {
  test('MonitorArcGeometry: 0% at start, 100% at end of 270° sweep', () {
    final a0 = MonitorArcGeometry.angleForProgress(0);
    final a1 = MonitorArcGeometry.angleForProgress(1);
    expect(a0, MonitorArcGeometry.startAngle);
    expect(a1, MonitorArcGeometry.startAngle + MonitorArcGeometry.sweepAngle);
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
}
