import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

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
      final l10n = AppLocalizations.of(context)!;
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
          SettingsSectionHeader(l10n.advancedSettingsGroupOffsetCorrection),
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
                  height: SettingsScaledParam.headerControlHeight,
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
          SettingsSectionHeader(l10n.advancedSettingsGroupPowerThresholds),
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
          SettingsSectionHeader(l10n.advancedSettingsGroupTemperatureThresholds),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Motor Temperature Alarm Threshold',
                value: v.motorTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${v.motorTempAlarm.round()}℃',
                scaleMinText: l10n.advancedSettingScale0Celsius,
                scaleMaxText: l10n.advancedSettingScale80Celsius,
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
                scaleMinText: l10n.advancedSettingScale0Celsius,
                scaleMaxText: l10n.advancedSettingScale80Celsius,
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
                scaleMinText: l10n.advancedSettingScale0Celsius,
                scaleMaxText: l10n.advancedSettingScale80Celsius,
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
                scaleMinText: l10n.advancedSettingScale0Celsius,
                scaleMaxText: l10n.advancedSettingScale80Celsius,
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
          SettingsSectionHeader(l10n.advancedSettingsGroupAiAssistance),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: l10n.advancedSettingLensContaminationDetection,
                value: ai?.lensContaminationDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (x) => unawaited(
                          ai.setLensContaminationDetectionEnabled(x),
                        ),
              ),
              SettingsSwitchRow(
                title: l10n.advancedSettingZeroPointOffsetDetection,
                value: ai?.zeroPointOffsetDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (x) => unawaited(
                          ai.setZeroPointOffsetDetectionEnabled(x),
                        ),
              ),
            ],
          ),
          SettingsSectionHeader(l10n.advancedSettingsGroupDangerousOperations),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: l10n.advancedSettingKeepLaserOnWhileAlarmed,
                subtitle: l10n.advancedSettingKeepLaserOnWhileAlarmedHint,
                value: dangerous?.keepLaserOnWhileAlarmed ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setKeepLaserOnWhileAlarmed(x),
                        ),
              ),
              SettingsSwitchRow(
                title: l10n.advancedSettingAllowWorkAfterCameraAlarm,
                subtitle: l10n.advancedSettingAllowWorkAfterCameraAlarmHint,
                value: dangerous?.allowWorkAfterCameraAlarm ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterCameraAlarm(x),
                        ),
              ),
              SettingsSwitchRow(
                title: l10n.advancedSettingAllowWorkAfterGasAlarm,
                subtitle: l10n.advancedSettingAllowWorkAfterGasAlarmHint,
                value: dangerous?.allowWorkAfterGasAlarm ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterGasAlarm(x),
                        ),
              ),
              SettingsSwitchRow(
                title: l10n.advancedSettingAllowWorkAfterLensContamination,
                subtitle:
                    l10n.advancedSettingAllowWorkAfterLensContaminationHint,
                value: dangerous?.allowWorkAfterLensContamination ?? false,
                onChanged: dangerous == null
                    ? null
                    : (x) => unawaited(
                          dangerous.setAllowWorkAfterLensContamination(x),
                        ),
              ),
              SettingsSwitchRow(
                title: l10n.advancedSettingAllowWorkAfterFeederAlarm,
                subtitle: l10n.advancedSettingAllowWorkAfterFeederAlarmHint,
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
