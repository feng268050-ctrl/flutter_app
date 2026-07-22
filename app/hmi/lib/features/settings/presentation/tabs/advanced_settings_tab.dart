import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// Advanced Settings — layout parity with lws-ui `AdvancedSettingFragment`.
///
/// Section order: Offset → Power → Temperature → AI Assistance → Dangerous.
/// Threshold cards use [SettingsParamCard] + [CyberScaledSlider] (local UI
/// state; Modbus bind via `AdvancedSettingsModbusIds` when wired).
class AdvancedSettingsTab extends StatefulWidget {
  const AdvancedSettingsTab({super.key});

  @override
  State<AdvancedSettingsTab> createState() => _AdvancedSettingsTabState();
}

class _AdvancedSettingsTabState extends State<AdvancedSettingsTab> {
  // Defaults match lws-ui DefaultValueUtils.createDefaultAdvancedSettings().
  double _zeroPointCorrection = 0;
  double _properSwingWidth = 0;
  double _laserStartPower = 10;
  double _laserEndPower = 10;
  double _blowPressureThreshold = 0;
  double _motorTempAlarm = 70;
  double _driverTempAlarm = 70;
  double _protectiveLensTempAlarm = 70;
  double _collimatingLensTempAlarm = 65;
  double _tempAlarmRecoveryInterval = 5;

  @override
  Widget build(BuildContext context) {
    final store = AdvancedSettingsScope.maybeOf(context);
    final ai = AdvancedSettingsScope.maybeAiOf(context);
    final dangerous = AdvancedSettingsScope.maybeDangerousOf(context);

    Widget body() {
      return SettingsScrollView(
        children: [
          const SettingsSectionHeader('Offset & Correction'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Zero Offset',
                value: _zeroPointCorrection,
                min: -30,
                max: 30,
                onChanged: (v) =>
                    setState(() => _zeroPointCorrection = v.roundToDouble()),
                trailing: CyberButton(
                  size: CyberButtonSize.small,
                  onPressed: () => setState(() => _zeroPointCorrection = 0),
                  child: const Text('Auto'),
                ),
              ),
              right: SettingsScaledParam(
                title: 'Proper Swing Width',
                value: _properSwingWidth,
                min: -75,
                max: 75,
                onChanged: (v) =>
                    setState(() => _properSwingWidth = v.roundToDouble()),
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
                value: _laserStartPower,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    setState(() => _laserStartPower = v.roundToDouble()),
              ),
              right: SettingsScaledParam(
                title: 'Laser Ending Power',
                value: _laserEndPower,
                min: 0,
                max: 100,
                onChanged: (v) =>
                    setState(() => _laserEndPower = v.roundToDouble()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsScaledParam(
              title: 'Blow Pressure Threshold',
              value: _blowPressureThreshold,
              min: 0,
              max: 400,
              onChanged: (v) =>
                  setState(() => _blowPressureThreshold = v.roundToDouble()),
            ),
          ),
          const SizedBox(height: 8),
          const SettingsSectionHeader('Temperature Thresholds'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Motor Temperature Alarm Threshold',
                value: _motorTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${_motorTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (v) =>
                    setState(() => _motorTempAlarm = v.roundToDouble()),
              ),
              right: SettingsScaledParam(
                title: 'Driver Temperature Alarm Threshold',
                value: _driverTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${_driverTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (v) =>
                    setState(() => _driverTempAlarm = v.roundToDouble()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: 'Protective Lens Temperature Alarm Threshold',
                value: _protectiveLensTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${_protectiveLensTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (v) => setState(
                  () => _protectiveLensTempAlarm = v.roundToDouble(),
                ),
              ),
              right: SettingsScaledParam(
                title: 'Collimating Lens Temperature Alarm Threshold',
                value: _collimatingLensTempAlarm,
                min: 0,
                max: 80,
                valueLabel: '${_collimatingLensTempAlarm.round()}℃',
                scaleMinText: '0℃',
                scaleMaxText: '80℃',
                onChanged: (v) => setState(
                  () => _collimatingLensTempAlarm = v.roundToDouble(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsScaledParam(
              title: 'Temperature Alarm Recovery Interval',
              value: _tempAlarmRecoveryInterval,
              min: 0,
              max: 20,
              onChanged: (v) => setState(
                () => _tempAlarmRecoveryInterval = v.roundToDouble(),
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
                    : (v) => unawaited(
                          ai.setLensContaminationDetectionEnabled(v),
                        ),
              ),
              SettingsSwitchRow(
                title: 'Zero Point Offset Detection',
                value: ai?.zeroPointOffsetDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (v) => unawaited(
                          ai.setZeroPointOffsetDetectionEnabled(v),
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
                    : (v) => unawaited(
                          dangerous.setKeepLaserOnWhileAlarmed(v),
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
                    : (v) => unawaited(
                          dangerous.setAllowWorkAfterCameraAlarm(v),
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
                    : (v) => unawaited(
                          dangerous.setAllowWorkAfterGasAlarm(v),
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
                    : (v) => unawaited(
                          dangerous.setAllowWorkAfterLensContamination(v),
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
                    : (v) => unawaited(
                          dangerous.setAllowWorkAfterFeederAlarm(v),
                        ),
              ),
            ],
          ),
        ],
      );
    }

    if (store == null) {
      return body();
    }
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => body(),
    );
  }
}
