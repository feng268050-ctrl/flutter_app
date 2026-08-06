import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';

void main() {
  group('AdvancedSettingsStore', () {
    test('defaults when JSON missing', () async {
      final dir = await Directory.systemTemp.createTemp('adv-');
      final store = AdvancedSettingsStore(
        preferencePath: '${dir.path}/advanced-settings.json',
      );
      store.warmRead();
      expect(store.lensContaminationDetectionEnabled, isTrue);
      expect(store.zeroPointOffsetDetectionEnabled, isTrue);
      expect(store.keepLaserOnWhileAlarmed, isFalse);
      expect(store.allowWorkAfterCameraAlarm, isFalse);
      expect(store.allowWorkAfterGasAlarm, isFalse);
      expect(store.allowWorkAfterLensContamination, isFalse);
      expect(store.allowWorkAfterFeederAlarm, isFalse);
      expect(store.thresholds.inletGasPressureThreshold, 0.0);
      expect(store.thresholds.laserStartPower, 10.0);
      expect(store.thresholds.motorTempAlarm, 70.0);
      expect(store.thresholds.collimatingLensTempAlarm, 65.0);
      expect(store.thresholds.tempAlarmRecoveryInterval, 5.0);
      expect(store.thresholds.zeroPointCorrection, 0.0);
      await dir.delete(recursive: true);
    });

    test('heals zeroed product defaults from Modbus clobber', () async {
      final dir = await Directory.systemTemp.createTemp('adv-heal-');
      final path = '${dir.path}/advanced-settings.json';
      await File(path).writeAsString(jsonEncode({
        'lensContaminationDetectionEnabled': true,
        'zeroPointOffsetDetectionEnabled': true,
        'keepLaserOnWhileAlarmed': false,
        'allowWorkAfterCameraAlarm': false,
        'allowWorkAfterGasAlarm': false,
        'allowWorkAfterLensContamination': false,
        'allowWorkAfterFeederAlarm': false,
        'zeroPointCorrection': -6.0,
        'properSwingWidth': 5.0,
        'laserStartPower': 0.0,
        'laserEndPower': 19.4,
        'blowPressureThreshold': 0.0,
        'inletGasPressureThreshold': 0.0,
        'motorTemperatureAlarmThreshold': 0.0,
        'driverTemperatureAlarmThreshold': 0.0,
        'protectiveLensTemperatureAlarmThreshold': 0.0,
        'collimatingLensTemperatureAlarmThreshold': 0.0,
        'temperatureAlarmRecoveryInterval': 0.0,
      }));
      final store = AdvancedSettingsStore(preferencePath: path);
      store.warmRead();
      expect(store.thresholds.zeroPointCorrection, -6.0);
      expect(store.thresholds.properSwingWidth, 5.0);
      expect(store.thresholds.laserStartPower, 10.0);
      expect(store.thresholds.laserEndPower, 19.4);
      expect(store.thresholds.motorTempAlarm, 70.0);
      expect(store.thresholds.driverTempAlarm, 70.0);
      expect(store.thresholds.protectiveLensTempAlarm, 70.0);
      expect(store.thresholds.collimatingLensTempAlarm, 65.0);
      expect(store.thresholds.tempAlarmRecoveryInterval, 5.0);
      expect(store.thresholds.blowPressureThreshold, 0.0);
      await dir.delete(recursive: true);
    });

    test('JSON round-trip for AI and dangerous toggles', () async {
      final dir = await Directory.systemTemp.createTemp('adv-');
      final path = '${dir.path}/advanced-settings.json';
      final store = AdvancedSettingsStore(preferencePath: path);
      store.warmRead();
      await store.setLensContaminationDetectionEnabled(false);
      await store.setKeepLaserOnWhileAlarmed(true);
      await store.setAllowWorkAfterGasAlarm(true);

      final again = AdvancedSettingsStore(preferencePath: path);
      again.warmRead();
      expect(again.lensContaminationDetectionEnabled, isFalse);
      expect(again.zeroPointOffsetDetectionEnabled, isTrue);
      expect(again.keepLaserOnWhileAlarmed, isTrue);
      expect(again.allowWorkAfterGasAlarm, isTrue);

      final decoded = jsonDecode(await File(path).readAsString()) as Map;
      expect(decoded['lensContaminationDetectionEnabled'], isFalse);
      expect(decoded['keepLaserOnWhileAlarmed'], isTrue);
      expect(decoded['allowWorkAfterGasAlarm'], isTrue);

      await dir.delete(recursive: true);
    });

    test('JSON round-trip for inlet gas pressure threshold', () async {
      final dir = await Directory.systemTemp.createTemp('adv-inlet-');
      final path = '${dir.path}/advanced-settings.json';
      final store = AdvancedSettingsStore(preferencePath: path);
      store.warmRead();
      await store.setThresholds(
        store.thresholds.copyWith(inletGasPressureThreshold: 42),
      );

      final again = AdvancedSettingsStore(preferencePath: path);
      again.warmRead();
      expect(again.thresholds.inletGasPressureThreshold, 42);

      final decoded = jsonDecode(await File(path).readAsString()) as Map;
      expect(decoded['inletGasPressureThreshold'], 42);

      await dir.delete(recursive: true);
    });

    test('corrupt JSON soft-fails to defaults', () async {
      final dir = await Directory.systemTemp.createTemp('adv-');
      final path = '${dir.path}/advanced-settings.json';
      await File(path).writeAsString('not-json{{{');
      final store = AdvancedSettingsStore(preferencePath: path);
      store.warmRead();
      expect(store.lensContaminationDetectionEnabled, isTrue);
      expect(store.keepLaserOnWhileAlarmed, isFalse);
      await dir.delete(recursive: true);
    });

    test('Advanced toggles do not touch Misc JSON', () async {
      final dir = await Directory.systemTemp.createTemp('adv-misc-');
      final advPath = '${dir.path}/advanced-settings.json';
      final miscPath = '${dir.path}/misc-settings.json';
      final misc = MiscSettingsStore(
        preferencePath: miscPath,
        legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
      );
      misc.warmRead();
      await misc.setShowSystemStatusOverlay(true);

      final adv = AdvancedSettingsStore(preferencePath: advPath);
      adv.warmRead();
      await adv.setAllowWorkAfterCameraAlarm(true);

      expect(File(advPath).existsSync(), isTrue);
      final miscDecoded =
          jsonDecode(await File(miscPath).readAsString()) as Map;
      expect(miscDecoded.containsKey('allowWorkAfterCameraAlarm'), isFalse);
      expect(miscDecoded['showSystemStatusOverlay'], isTrue);

      await dir.delete(recursive: true);
    });
  });

  group('LaserAlarmPolicy', () {
    test('bypassable codes', () {
      expect(LaserAlarmPolicy.isBypassableAlarmCode('A001'), isTrue);
      expect(LaserAlarmPolicy.isBypassableAlarmCode('C002'), isTrue);
      expect(LaserAlarmPolicy.isBypassableAlarmCode('L001'), isTrue);
      expect(LaserAlarmPolicy.isBypassableAlarmCode('W001'), isTrue);
      expect(LaserAlarmPolicy.isBypassableAlarmCode('W002'), isTrue);
      expect(LaserAlarmPolicy.isBypassableAlarmCode('X999'), isFalse);
    });

    test('allow-* clears specific blocks; keepLaserOn clears work block', () {
      expect(
        LaserAlarmPolicy.isGasBlocking(
          gasAlarmActive: true,
          allowWorkAfterGasAlarm: false,
        ),
        isTrue,
      );
      expect(
        LaserAlarmPolicy.isGasBlocking(
          gasAlarmActive: true,
          allowWorkAfterGasAlarm: true,
        ),
        isFalse,
      );

      final readyBlocked = LaserAlarmPolicy.isReadyIndicatorBlocked(
        gasBlocking: true,
        cameraBlocking: false,
        lensBlocking: false,
        feederBlocking: false,
        otherCodedWarnBlocking: false,
      );
      expect(readyBlocked, isTrue);
      expect(
        LaserAlarmPolicy.isWorkBlocked(
          keepLaserOnWhileAlarmed: false,
          readyIndicatorBlocked: readyBlocked,
        ),
        isTrue,
      );
      expect(
        LaserAlarmPolicy.isWorkBlocked(
          keepLaserOnWhileAlarmed: true,
          readyIndicatorBlocked: readyBlocked,
        ),
        isFalse,
      );
      // Ready path ignores keepLaserOn.
      expect(readyBlocked, isTrue);
    });

    test('treatBypassableAsInfo follows matching allow-*', () {
      const snap = LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: false,
        allowWorkAfterCameraAlarm: true,
        allowWorkAfterGasAlarm: false,
        allowWorkAfterLensContamination: false,
        allowWorkAfterFeederAlarm: true,
      );
      expect(
        LaserAlarmPolicy.treatBypassableAsInfo(code: 'C002', snapshot: snap),
        isTrue,
      );
      expect(
        LaserAlarmPolicy.treatBypassableAsInfo(code: 'A001', snapshot: snap),
        isFalse,
      );
      expect(
        LaserAlarmPolicy.treatBypassableAsInfo(code: 'W001', snapshot: snap),
        isTrue,
      );
    });
  });

  group('DangerousOperationsSettings', () {
    test('onBypassDisabled fires when toggle turns OFF', () async {
      final dir = await Directory.systemTemp.createTemp('adv-');
      final store = AdvancedSettingsStore(
        preferencePath: '${dir.path}/advanced-settings.json',
      );
      store.warmRead();
      var calls = 0;
      final facade = DangerousOperationsSettings(
        store,
        onBypassDisabled: () => calls++,
      );
      await facade.setAllowWorkAfterGasAlarm(true);
      expect(calls, 0);
      await facade.setAllowWorkAfterGasAlarm(false);
      expect(calls, 1);
      facade.dispose();
      await dir.delete(recursive: true);
    });
  });

  group('laserEndPowerFromProcess', () {
    test('matches lws-ui LASER_END_POWER_RATIO 0.97', () {
      expect(
        AdvancedSettingsThresholdValues.laserEndPowerFromProcess(100),
        97,
      );
      expect(
        AdvancedSettingsThresholdValues.laserEndPowerFromProcess(55),
        closeTo(53.35, 1e-9),
      );
    });
  });
}
