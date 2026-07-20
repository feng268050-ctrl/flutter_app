import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';

void main() {
  test('MonitorArcGeometry: 0% at start, 100% at end of 270° sweep', () {
    final a0 = MonitorArcGeometry.angleForProgress(0);
    final a1 = MonitorArcGeometry.angleForProgress(1);
    expect(a0, MonitorArcGeometry.startAngle);
    expect(a1, MonitorArcGeometry.startAngle + MonitorArcGeometry.sweepAngle);
  });
}
