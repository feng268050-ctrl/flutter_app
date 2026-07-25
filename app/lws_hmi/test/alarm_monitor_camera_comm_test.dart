import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';

void main() {
  test('setCameraCommFault notifies and maps idle/ok/fault', () {
    final monitor = AlarmMonitorState();
    var notified = 0;
    monitor.addListener(() => notified++);

    expect(monitor.cameraCommFault, isNull);

    monitor.setCameraCommFault(true);
    expect(monitor.cameraCommFault, isTrue);
    expect(notified, 1);

    monitor.setCameraCommFault(true);
    expect(notified, 1);

    monitor.setCameraCommFault(false);
    expect(monitor.cameraCommFault, isFalse);
    expect(notified, 2);
  });
}
