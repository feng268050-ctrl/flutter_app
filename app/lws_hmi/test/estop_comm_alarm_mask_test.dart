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

    test('key switch off suppresses H022 only', () {
      expect(
        EstopCommAlarmMask.laserCommEffectiveActive(
          raw: true,
          eStopActive: false,
          keySwitchOn: false,
        ),
        isFalse,
      );
      expect(
        EstopCommAlarmMask.laserCommEffectiveActive(
          raw: true,
          eStopActive: false,
          keySwitchOn: true,
        ),
        isTrue,
      );
    });

    test('laser comm, wire-feeder comm, and H029 attrs are masked', () {
      expect(EstopCommAlarmMask.isMaskedAttr('alarm.laser_comm'), isTrue);
      expect(
        EstopCommAlarmMask.isMaskedAttr('alarm.wire_feeder_comm'),
        isTrue,
      );
      expect(
        EstopCommAlarmMask.isMaskedAttr('alarm.laser_emergency_stop'),
        isTrue,
      );
      expect(EstopCommAlarmMask.isMaskedAttr('alarm.gun_comm'), isFalse);
      expect(
        EstopCommAlarmMask.isMaskedAttr('alarm.wire_feeder_current'),
        isFalse,
      );
      expect(
        EstopCommAlarmMask.isMaskedAttr('machine.emergency_stop'),
        isFalse,
      );
    });
  });
}
