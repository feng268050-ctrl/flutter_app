import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_threshold_codec.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';

void main() {
  group('AdvancedSettingsThresholdCodec', () {
    test('laser and zero encode/decode', () {
      expect(
        AdvancedSettingsThresholdCodec.toWire(
          AdvancedSettingsModbusIds.laserStartPower,
          10,
        ),
        1000,
      );
      expect(
        AdvancedSettingsThresholdCodec.fromWire(
          AdvancedSettingsModbusIds.laserStartPower,
          1000,
        ),
        10,
      );
      expect(
        AdvancedSettingsThresholdCodec.toWire(
          AdvancedSettingsModbusIds.zeroPointCorrection,
          -12,
        ),
        -120,
      );
      expect(
        AdvancedSettingsThresholdCodec.fromWire(
          AdvancedSettingsModbusIds.zeroPointCorrection,
          -120,
        ),
        -12,
      );
    });

    test('swing offset +75', () {
      // -75 + 75 = 0 → coerce to 1 (lws-ui)
      expect(
        AdvancedSettingsThresholdCodec.toWire(
          AdvancedSettingsModbusIds.swingWidthCorrection,
          -75,
        ),
        1,
      );
      expect(
        AdvancedSettingsThresholdCodec.toWire(
          AdvancedSettingsModbusIds.swingWidthCorrection,
          0,
        ),
        75,
      );
      expect(
        AdvancedSettingsThresholdCodec.fromWire(
          AdvancedSettingsModbusIds.swingWidthCorrection,
          75,
        ),
        0,
      );
    });

    test('temps pass engineering to HAL scale', () {
      expect(
        AdvancedSettingsThresholdCodec.toWire(
          AdvancedSettingsModbusIds.motorTempAlarmThreshold,
          70,
        ),
        70,
      );
    });
  });

  test('treatBypassableAsInfo for warn chrome', () {
    const snap = LaserAlarmPolicySnapshot(
      keepLaserOnWhileAlarmed: false,
      allowWorkAfterCameraAlarm: false,
      allowWorkAfterGasAlarm: true,
      allowWorkAfterLensContamination: false,
      allowWorkAfterFeederAlarm: false,
    );
    expect(
      LaserAlarmPolicy.treatBypassableAsInfo(code: 'A001', snapshot: snap),
      isTrue,
    );
    expect(
      LaserAlarmPolicy.treatBypassableAsInfo(code: 'C002', snapshot: snap),
      isFalse,
    );
  });
}
