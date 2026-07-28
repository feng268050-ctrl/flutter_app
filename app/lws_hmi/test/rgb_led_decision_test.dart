import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/gpio/rgb_led_decision.dart';

void main() {
  const snapAllOff = LaserAlarmPolicySnapshot(
    keepLaserOnWhileAlarmed: false,
    allowWorkAfterCameraAlarm: false,
    allowWorkAfterGasAlarm: false,
    allowWorkAfterLensContamination: false,
    allowWorkAfterFeederAlarm: false,
  );

  group('RgbLedDecision.redMode', () {
    test('off when not primed', () {
      expect(
        RgbLedDecision.redMode(
          primed: false,
          laserOn: false,
          laserCommAlarm: false,
        ),
        IndicatorMode.off,
      );
    });

    test('steady when emitting', () {
      expect(
        RgbLedDecision.redMode(
          primed: true,
          laserOn: true,
          laserCommAlarm: false,
        ),
        IndicatorMode.steadyOn,
      );
    });

    test('off when H022 laser comm alarm', () {
      expect(
        RgbLedDecision.redMode(
          primed: true,
          laserOn: false,
          laserCommAlarm: true,
        ),
        IndicatorMode.off,
      );
    });

    test('blink standby when online and not emitting', () {
      expect(
        RgbLedDecision.redMode(
          primed: true,
          laserOn: false,
          laserCommAlarm: false,
        ),
        IndicatorMode.blink,
      );
    });
  });

  group('RgbLedDecision.yellowMode', () {
    test('blink on WARN-severity active', () {
      expect(
        RgbLedDecision.yellowMode(hasWarnSeverityAlarm: true),
        IndicatorMode.blink,
      );
    });

    test('off when no WARN-severity', () {
      expect(
        RgbLedDecision.yellowMode(hasWarnSeverityAlarm: false),
        IndicatorMode.off,
      );
    });

    test('bypassed C002 alone is not yellow', () {
      final snap = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: false,
        allowWorkAfterCameraAlarm: true,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: false,
      );
      expect(
        RgbLedDecision.hasAnyActiveWarnSeverity(
          activeCodes: {'C002'},
          snapshot: snap,
        ),
        isFalse,
      );
    });

    test('A001 stays yellow even when gas bypass demotes dialog to INFO', () {
      final snap = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: false,
        allowWorkAfterCameraAlarm: false,
        allowWorkAfterGasAlarm: true,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: false,
      );
      expect(
        RgbLedDecision.hasAnyActiveWarnSeverity(
          activeCodes: {'A001'},
          snapshot: snap,
        ),
        isTrue,
      );
    });

    test('bypassed feeder alone is not yellow', () {
      final snap = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: false,
        allowWorkAfterCameraAlarm: false,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: true,
      );
      expect(
        RgbLedDecision.hasAnyActiveWarnSeverity(
          activeCodes: {'W001'},
          snapshot: snap,
        ),
        isFalse,
      );
    });

    test('non-bypassable code is yellow even with keepLaserOn', () {
      final snap = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: true,
        allowWorkAfterCameraAlarm: false,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: false,
      );
      expect(
        RgbLedDecision.hasAnyActiveWarnSeverity(
          activeCodes: {'H022'},
          snapshot: snap,
        ),
        isTrue,
      );
    });
  });

  group('RgbLedDecision.greenMode', () {
    test('steady when enable + clamp + key (standard mode)', () {
      expect(
        RgbLedDecision.greenMode(
          primed: true,
          laserOn: false,
          keySwitchOn: true,
          readyIndicatorBlocked: false,
          laserEnableActive: true,
          safetyGroundLockLocked: true,
          cncMode: false,
          cncConnected: false,
        ),
        IndicatorMode.steadyOn,
      );
    });

    test('off when ready blocked (keepLaserOn does not clear via caller)', () {
      expect(
        RgbLedDecision.greenMode(
          primed: true,
          laserOn: false,
          keySwitchOn: true,
          readyIndicatorBlocked: true,
          laserEnableActive: true,
          safetyGroundLockLocked: true,
          cncMode: false,
          cncConnected: false,
        ),
        IndicatorMode.off,
      );
    });

    test('CNC steady when connected; ignores enable/clamp', () {
      expect(
        RgbLedDecision.greenMode(
          primed: true,
          laserOn: false,
          keySwitchOn: true,
          readyIndicatorBlocked: false,
          laserEnableActive: false,
          safetyGroundLockLocked: false,
          cncMode: true,
          cncConnected: true,
        ),
        IndicatorMode.steadyOn,
      );
    });

    test('CNC off when not connected', () {
      expect(
        RgbLedDecision.greenMode(
          primed: true,
          laserOn: false,
          keySwitchOn: true,
          readyIndicatorBlocked: false,
          laserEnableActive: true,
          safetyGroundLockLocked: true,
          cncMode: true,
          cncConnected: false,
        ),
        IndicatorMode.off,
      );
    });

    test('ready block ignores keepLaserOn', () {
      final snap = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: true,
        allowWorkAfterCameraAlarm: false,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: false,
      );
      expect(
        RgbLedDecision.readyIndicatorBlockedFromActive(
          activeCodes: {'E006'},
          snapshot: snap,
        ),
        isTrue,
      );
      expect(
        LaserAlarmPolicy.isWorkBlocked(
          keepLaserOnWhileAlarmed: true,
          readyIndicatorBlocked: true,
        ),
        isFalse,
      );
    });

    test('unused snapAllOff constant for clarity', () {
      expect(snapAllOff.keepLaserOnWhileAlarmed, isFalse);
    });
  });
}
