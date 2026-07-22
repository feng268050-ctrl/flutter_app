import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/estop_comm_alarm_mask.dart';

void main() {
  group('EstopCommAlarmMask', () {
    test('e-stop off keeps raw', () {
      expect(
        EstopCommAlarmMask.effectiveActive(raw: true, eStopActive: false),
        isTrue,
      );
      expect(
        EstopCommAlarmMask.effectiveActive(raw: false, eStopActive: false),
        isFalse,
      );
    });

    test('e-stop on forces inactive', () {
      expect(
        EstopCommAlarmMask.effectiveActive(raw: true, eStopActive: true),
        isFalse,
      );
      expect(
        EstopCommAlarmMask.effectiveActive(raw: false, eStopActive: true),
        isFalse,
      );
    });

    test('only laser and wire-feeder comm attrs are masked', () {
      expect(EstopCommAlarmMask.isMaskedCommAttr('alarm.laser_comm'), isTrue);
      expect(
        EstopCommAlarmMask.isMaskedCommAttr('alarm.wire_feeder_comm'),
        isTrue,
      );
      expect(EstopCommAlarmMask.isMaskedCommAttr('alarm.gun_comm'), isFalse);
      expect(
        EstopCommAlarmMask.isMaskedCommAttr('alarm.wire_feeder_current'),
        isFalse,
      );
      expect(
        EstopCommAlarmMask.isMaskedCommAttr('machine.emergency_stop'),
        isFalse,
      );
    });
  });
}
