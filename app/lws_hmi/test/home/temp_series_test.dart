import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';

void main() {
  test('TempSeries sticky trend when value unchanged', () {
    final s = TempSeries();
    s.setCelsius(20);
    expect(s.trend, TempTrend.none);

    s.setCelsius(21);
    expect(s.trend, TempTrend.up);

    s.setCelsius(21);
    expect(s.trend, TempTrend.up);

    s.setCelsius(19);
    expect(s.trend, TempTrend.down);

    s.setCelsius(19);
    expect(s.trend, TempTrend.down);
  });

  test('TempSeries clears trend when unavailable', () {
    final s = TempSeries();
    s.setCelsius(20);
    s.setCelsius(22);
    expect(s.trend, TempTrend.up);

    s.setCelsius(null);
    expect(s.lastCelsius, isNull);
    expect(s.trend, TempTrend.none);
  });
}
