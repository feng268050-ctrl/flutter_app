import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// Advanced Settings — layout parity with lws-ui `AdvancedSettingFragment`.
///
/// Thresholds: Modbus watch/write via [AdvancedSettingsThresholdsController].
/// Zero Offset Auto is local reset only (full Auto procedure out of scope).
class AdvancedSettingsTab extends StatefulWidget {
  const AdvancedSettingsTab({super.key});

  @override
  State<AdvancedSettingsTab> createState() => _AdvancedSettingsTabState();
}

class _AdvancedSettingsTabState extends State<AdvancedSettingsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = AdvancedSettingsScope.maybeThresholdsOf(context);
      unawaited(t?.start());
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AdvancedSettingsScope.maybeOf(context);
    final ai = AdvancedSettingsScope.maybeAiOf(context);
    final dangerous = AdvancedSettingsScope.maybeDangerousOf(context);
    final thresholds = AdvancedSettingsScope.maybeThresholdsOf(context);

    Widget body() {
      final v = thresholds?.values ??
          store?.thresholds ??
          const AdvancedSettingsThresholdValues();

      Future<void> commit(
        String id,
        AdvancedSettingsThresholdValues next,
      ) async {
        final t = thresholds;
        if (t != null) {
          await t.commitField(id, next);
        } else if (store != null) {
          await store.setThresholds(next);
        }
        if (mounted) setState(() {});
      }

      void preview(AdvancedSettingsThresholdValues next) {
        thresholds?.preview(next);
        if (mounted) setState(() {});
      }

      return SettingsScrollView(
        children: [
          const SettingsSectionHeader('Offset & Correction'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Zero Offset',
                value: v.zeroPointCorrection,
                min: -30,
                max: 30,
                onChanged: (n) => preview(
                  v.copyWith(zeroPointCorrection: n.roundToDouble()),
                ),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.zeroPointCorrection,
                    v.copyWith(zeroPointCorrection: n.roundToDouble()),
                  ),
                ),
                trailing: CyberButton(
                  size: CyberButtonSize.small,
                  onPressed: () => unawaited(
                    commit(
                      AdvancedSettingsModbusIds.zeroPointCorrection,
                      v.copyWith(zeroPointCorrection: 0),
                    ),
                  ),
                  child: const Text('Auto'),
                ),
              ),
              right: SettingsScaledParam(
                title: 'Proper Swing Width',
                value: v.properSwingWidth,
                min: -75,
                max: 75,
                onChanged: (n) => preview(
                  v.copyWith(properSwingWidth: n.roundToDouble()),
                ),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.swingWidthCorrection,
                    v.copyWith(properSwingWidth: n.roundToDouble()),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SettingsSectionHeader('Power Thresholds'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Laser Starting Power',
                value: v.laserStartPower,
                min: 0,
                max: 100,
                onChanged: (n) =>
                    preview(v.copyWith(laserStartPower: n.roundToDouble())),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.laserStartPower,
                    v.copyWith(laserStartPower: n.roundToDouble()),
                  ),
                ),
              ),
              right: SettingsScaledParam(
                title: 'Laser Ending Power',
                value: v.laserEndPower,
                min: 0,
                max: 100,
                onChanged: (n) =>
                    preview(v.copyWith(laserEndPower: n.roundToDouble())),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.laserEndPower,
                    v.copyWith(laserEndPower: n.roundToDouble()),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsScaledParam(
              title: 'Blow Pressure Threshold',
              value: v.blowPressureThreshold,
              min: 0,
              max: 400,
              onChanged: (n) => preview(
                v.copyWith(blowPressureThreshold: n.roundToDouble()),
              ),
              onChangeEnd: (n) => unawaited(
                commit(
                  AdvancedSettingsModbusIds.blowingPressureThreshold,
                  v.copyWith(blowPressureThreshold: n.roundToDouble()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SettingsSectionHeader('Temperature Thresholds'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Motor Temperature Alarm Threshold',
                value: v.motorTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${v.motorTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (n) =>
                    preview(v.copyWith(motorTempAlarm: n.roundToDouble())),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.motorTempAlarmThreshold,
                    v.copyWith(motorTempAlarm: n.roundToDouble()),
                  ),
                ),
              ),
              right: SettingsScaledParam(
                title: 'Driver Temperature Alarm Threshold',
                value: v.driverTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${v.driverTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (n) =>
                    preview(v.copyWith(driverTempAlarm: n.roundToDouble())),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.driverTempAlarmThreshold,
                    v.copyWith(driverTempAlarm: n.roundToDouble()),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Protective Lens Temperature Alarm Threshold',
                value: v.protectiveLensTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${v.protectiveLensTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (n) => preview(
                  v.copyWith(protectiveLensTempAlarm: n.roundToDouble()),
                ),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold,
                    v.copyWith(protectiveLensTempAlarm: n.roundToDouble()),
                  ),
                ),
              ),
              right: SettingsScaledParam(
                title: 'Collimating Lens Temperature Alarm Threshold',
                value: v.collimatingLensTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${v.collimatingLensTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (n) => preview(
                  v.copyWith(collimatingLensTempAlarm: n.roundToDouble()),
                ),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.collimatingLensTempAlarmThreshold,
                    v.copyWith(collimatingLensTempAlarm: n.roundToDouble()),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsScaledParam(
              title: 'Temperature Alarm Recovery Interval',
              value: v.tempAlarmRecoveryInterval,
              min: 0,
              max: 20,
              onChanged: (n) => preview(
                v.copyWith(tempAlarmRecoveryInterval: n.roundToDouble()),
              ),
              onChangeEnd: (n) => unawaited(
                commit(
                  AdvancedSettingsModbusIds.tempAlarmRecoveryInterval,
                  v.copyWith(tempAlarmRecoveryInterval: n.roundToDouble()),
                ),
              ),
            ),
          ),
          const SettingsSectionHeader('AI Assistance'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Lens Contamination Detection',
                value: ai?.lensContaminationDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (x) => unawaited(
                          ai.setLensContaminationDetectionEnabled(x),
                        ),
              ),
              SettingsSwitchRow(
                title: 'Zero Point Offset Detection',
                value: ai?.zeroPointOffsetDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (x) => unawaited(
                          ai.setZeroPointOffsetDetectionEnabled(x),
                        ),
              ),
            ],
          ),
          const SettingsSectionHeader('Dangerous Operations'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Keep Laser On while Alarmed',
                subtitle:
                    'When enabled, coded alarms will not automatically turn '
                    'off laser output while you are already welding. Warn '
                    'dialogs still appear.',
                value: dangerous?.keepLaserOnWhileAlarmed ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setKeepLaserOnWhileAlarmed(x),
                        ),
              ),
              SettingsSwitchRow(
                title: 'Allow Work after Camera Alarm',
                subtitle:
                    'When camera communication is abnormal, AI automatic '
                    'detection will be unavailable.',
                value: dangerous?.allowWorkAfterCameraAlarm ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterCameraAlarm(x),
                        ),
              ),
              SettingsSwitchRow(
                title: 'Allow Work after Gas Alarm',
                subtitle:
                    'Allowing laser output while shielding gas is abnormal '
                    'may damage your device. Turn this on only when you are '
                    'sure there is no impact.',
                value: dangerous?.allowWorkAfterGasAlarm ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterGasAlarm(x),
                        ),
              ),
              SettingsSwitchRow(
                title: 'Allow Work after Lens Contamination',
                subtitle:
                    'Allowing laser output while the protective lens is '
                    'contaminated may damage your device. Turn this on only '
                    'when AI detection is inaccurate.',
                value: dangerous?.allowWorkAfterLensContamination ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterLensContamination(x),
                        ),
              ),
              SettingsSwitchRow(
                title: 'Allow Work after Feeder Alarm',
                subtitle:
                    'Continuous welding will not work properly when the wire '
                    'feeder is abnormal, but other modes can continue.',
                value: dangerous?.allowWorkAfterFeederAlarm ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterFeederAlarm(x),
                        ),
              ),
            ],
          ),
        ],
      );
    }

    final listenables = <Listenable>[
      if (store != null) store,
      if (thresholds != null) thresholds,
    ];
    if (listenables.isEmpty) {
      return body();
    }
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => body(),
    );
  }
}
