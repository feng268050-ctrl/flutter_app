import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/home/presentation/temp_trend_arrows.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[HmiTypography()],
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('MonitorTempMetricCard keeps fixed arrow slot after value',
      (tester) async {
    final rising = TempSeries()
      ..setCelsius(20)
      ..setCelsius(25);
    expect(rising.trend, TempTrend.up);

    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 360,
          height: MonitorDimens.metricH,
          child: MonitorTempMetricCard(
            series: rising,
            label: 'Motor Temperature',
            overTemp: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TempTrendArrows), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

    final arrows = tester.widget<TempTrendArrows>(find.byType(TempTrendArrows));
    expect(arrows.trend, TempTrend.up);
    final size = tester.getSize(find.byType(TempTrendArrows));
    expect(size.width, TempTrendArrows.slotWidth);
    expect(size.height, TempTrendArrows.slotHeight);

    // Value and arrow sit on one tight row (arrow not pushed to the far right).
    final valueRect = tester.getRect(find.textContaining('°'));
    final arrowRect = tester.getRect(find.byType(TempTrendArrows));
    expect(arrowRect.left, lessThan(valueRect.right + TempTrendArrows.slotWidth + 4));
    expect(
      (valueRect.center.dy - arrowRect.center.dy).abs(),
      lessThan(4),
    );
  });

  testWidgets('MonitorTempMetricCard reserves arrow slot when trend is none',
      (tester) async {
    final series = TempSeries()..setCelsius(20);
    expect(series.trend, TempTrend.none);

    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 360,
          height: MonitorDimens.metricH,
          child: MonitorTempMetricCard(
            series: series,
            label: 'Motor Temperature',
            overTemp: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TempTrendArrows), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    expect(tester.getSize(find.byType(TempTrendArrows)).width,
        TempTrendArrows.slotWidth);
  });

  testWidgets('MonitorTempMetricCard wraps long temperature labels on word boundaries',
      (tester) async {
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 280,
          height: MonitorDimens.metricH,
          child: MonitorTempMetricCard(
            series: TempSeries()..setCelsius(20),
            label: 'Protective Mirror Temperature',
            overTemp: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(WordBoundaryLabel), findsOneWidget);
    expect(find.textContaining('Protective'), findsOneWidget);
    expect(find.textContaining('Temperature'), findsOneWidget);
    expect(find.text('Protective Mirror Temperature'), findsNothing);
  });

  testWidgets('MonitorTempMetricCard hides arrow slot when value unavailable',
      (tester) async {
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 360,
          height: MonitorDimens.metricH,
          child: MonitorTempMetricCard(
            series: TempSeries(),
            label: 'Motor Temperature',
            overTemp: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TempTrendArrows), findsNothing);
    expect(find.text('-'), findsOneWidget);
  });
}
