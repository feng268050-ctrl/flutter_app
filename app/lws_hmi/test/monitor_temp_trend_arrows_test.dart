import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/home/presentation/temp_trend_arrows.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

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

  testWidgets('MonitorTempMetricCard shows Live-parity trend arrows when rising',
      (tester) async {
    final series = TempSeries()
      ..setCelsius(20)
      ..setCelsius(25);
    expect(series.trend, TempTrend.up);

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
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    final arrows = tester.widget<TempTrendArrows>(find.byType(TempTrendArrows));
    expect(arrows.trend, TempTrend.up);

    final size = tester.getSize(find.byType(TempTrendArrows));
    expect(size.width, TempTrendArrows.size);
    expect(size.height, TempTrendArrows.slotHeight);
  });

  testWidgets('MonitorTempMetricCard hides arrows when value unavailable',
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
