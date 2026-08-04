import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/temperature_unit_convert.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/auto_zero_offset_dialog.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Advanced Settings — layout parity with lws-ui `AdvancedSettingFragment`.
///
/// Thresholds: Modbus watch/write via [AdvancedSettingsThresholdsController].
/// Temperature fields store °C; display follows Common Settings unit (°C/°F).
/// Value chips open CyberIME numeric dialogs (lws-ui FrostNumericInputDialog).
/// Zero Offset Auto opens the confirm dialog (AI procedure wired later).
class AdvancedSettingsTab extends StatefulWidget {
  const AdvancedSettingsTab({super.key});

  @override
  State<AdvancedSettingsTab> createState() => _AdvancedSettingsTabState();
}

class _AdvancedSettingsTabState extends State<AdvancedSettingsTab> {
  static const _hPad = EdgeInsets.symmetric(horizontal: SettingsDimens.inset);
  static const _cardGap = SizedBox(height: SettingsDimens.inset);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = AdvancedSettingsScope.maybeThresholdsOf(context);
      unawaited(t?.start());
    });
  }

  Future<void> _editInt({
    required String title,
    required String hint,
    required int displayValue,
    required int displayMin,
    required int displayMax,
    required bool signed,
    required ValueChanged<int> onCommitDisplay,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final raw = await showCyberImeInputDialog(
      context: context,
      title: title,
      hint: hint,
      label: title,
      initial: '$displayValue',
      fieldType: signed
          ? CyberImeFieldType.signedDecimal
          : CyberImeFieldType.number,
      confirmLabel: l10n.confirmText,
      requireNonEmpty: true,
      emptyErrorText: l10n.advancedSettingValueRequired,
    );
    if (raw == null || !mounted) return;
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    onCommitDisplay(parsed.clamp(displayMin, displayMax));
  }

  @override
  Widget build(BuildContext context) {
    final store = AdvancedSettingsScope.maybeOf(context);
    final ai = AdvancedSettingsScope.maybeAiOf(context);
    final dangerous = AdvancedSettingsScope.maybeDangerousOf(context);
    final thresholds = AdvancedSettingsScope.maybeThresholdsOf(context);
    final common = CommonSettingsScope.maybeOf(context);

    Widget body() {
      final l10n = AppLocalizations.of(context)!;
      final unit = common?.unit ?? CommonSettingsStore.defaultUnit;
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

      String tempLabel(int celsius) =>
          TemperatureUnitConvert.toDisplay(celsius, unit);

      String tempScale(int celsius) => TemperatureUnitConvert.formatScaleLabel(
            celsius,
            unit,
            celsiusUnit: l10n.celsiusUnit,
            fahrenheitUnit: l10n.fahrenheitUnit,
          );

      Future<void> editTempCelsius({
        required String title,
        required String hint,
        required int celsius,
        required int minC,
        required int maxC,
        required Future<void> Function(int nextC) onCommitC,
      }) async {
        final (dMin, dMax) =
            TemperatureUnitConvert.displayRange(minC, maxC, unit);
        final display = int.parse(TemperatureUnitConvert.toDisplay(celsius, unit));
        await _editInt(
          title: title,
          hint: hint,
          displayValue: display,
          displayMin: dMin,
          displayMax: dMax,
          signed: false,
          onCommitDisplay: (d) {
            final nextC = TemperatureUnitConvert.parseInputToCelsius(
              '$d',
              unit,
            ).clamp(minC, maxC);
            unawaited(onCommitC(nextC));
          },
        );
      }

      return SettingsScrollView(
        // Section headers own the 24 top inset (avoid double with default).
        padding: EdgeInsets.zero,
        children: [
          SettingsSectionHeader(l10n.advancedSettingsGroupOffsetCorrection),
          Padding(
            padding: _hPad,
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: l10n.advancedSettingZeroOffset,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
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
                onValueTap: () => unawaited(
                  _editInt(
                    title: l10n.advancedSettingZeroOffset,
                    hint: l10n.advancedSettingEnterZeroOffset,
                    displayValue: v.zeroPointCorrection.round(),
                    displayMin: -30,
                    displayMax: 30,
                    signed: true,
                    onCommitDisplay: (n) => unawaited(
                      commit(
                        AdvancedSettingsModbusIds.zeroPointCorrection,
                        v.copyWith(zeroPointCorrection: n.toDouble()),
                      ),
                    ),
                  ),
                ),
                trailing: HmiButton(
                  label: l10n.advancedSettingZeroOffsetAuto,
                  size: HmiButtonSize.mini,
                  variant: CyberButtonVariant.primary,
                  onPressed: () => unawaited(showAutoZeroOffsetDialog(
                    context: context,
                  )),
                ),
              ),
              right: SettingsScaledParam(
                title: l10n.advancedSettingScanWidthCorrection,
                borderGradientCenter:
                    CyberBorderGradientCenter.bottomLeftTopRight,
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
                onValueTap: () => unawaited(
                  _editInt(
                    title: l10n.advancedSettingScanWidthCorrection,
                    hint: l10n.advancedSettingEnterScanWidthCorrection,
                    displayValue: v.properSwingWidth.round(),
                    displayMin: -75,
                    displayMax: 75,
                    signed: true,
                    onCommitDisplay: (n) => unawaited(
                      commit(
                        AdvancedSettingsModbusIds.swingWidthCorrection,
                        v.copyWith(properSwingWidth: n.toDouble()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SettingsSectionHeader(
            l10n.advancedSettingsGroupPowerThresholds,
            topInset: 36,
          ),
          Padding(
            padding: _hPad,
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: l10n.advancedSettingLaserStartPower,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
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
                onValueTap: () => unawaited(
                  _editInt(
                    title: l10n.advancedSettingLaserStartPower,
                    hint: l10n.advancedSettingEnterLaserStartPower,
                    displayValue: v.laserStartPower.round(),
                    displayMin: 0,
                    displayMax: 100,
                    signed: false,
                    onCommitDisplay: (n) => unawaited(
                      commit(
                        AdvancedSettingsModbusIds.laserStartPower,
                        v.copyWith(laserStartPower: n.toDouble()),
                      ),
                    ),
                  ),
                ),
              ),
              right: SettingsScaledParam(
                title: l10n.advancedSettingLaserEndPower,
                borderGradientCenter:
                    CyberBorderGradientCenter.bottomLeftTopRight,
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
                onValueTap: () => unawaited(
                  _editInt(
                    title: l10n.advancedSettingLaserEndPower,
                    hint: l10n.advancedSettingEnterLaserEndPower,
                    displayValue: v.laserEndPower.round(),
                    displayMin: 0,
                    displayMax: 100,
                    signed: false,
                    onCommitDisplay: (n) => unawaited(
                      commit(
                        AdvancedSettingsModbusIds.laserEndPower,
                        v.copyWith(laserEndPower: n.toDouble()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _cardGap,
          Padding(
            padding: _hPad,
            child: SettingsScaledParam(
              title: l10n.advancedSettingMinGasPressure,
              borderGradientCenter: CyberBorderGradientCenter.topBottom,
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
              onValueTap: () => unawaited(
                _editInt(
                  title: l10n.advancedSettingMinGasPressure,
                  hint: l10n.advancedSettingEnterMinGasPressure,
                  displayValue: v.blowPressureThreshold.round(),
                  displayMin: 0,
                  displayMax: 400,
                  signed: false,
                  onCommitDisplay: (n) => unawaited(
                    commit(
                      AdvancedSettingsModbusIds.blowingPressureThreshold,
                      v.copyWith(blowPressureThreshold: n.toDouble()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _cardGap,
          Padding(
            padding: _hPad,
            child: SettingsScaledParam(
              title: l10n.advancedSettingInletGasPressure,
              borderGradientCenter: CyberBorderGradientCenter.topBottom,
              value: v.inletGasPressureThreshold,
              min: 0,
              max: 200,
              onChanged: (n) => preview(
                v.copyWith(inletGasPressureThreshold: n.roundToDouble()),
              ),
              onChangeEnd: (n) => unawaited(
                commit(
                  AdvancedSettingsModbusIds.inletGasPressureThreshold,
                  v.copyWith(inletGasPressureThreshold: n.roundToDouble()),
                ),
              ),
              onValueTap: () => unawaited(
                _editInt(
                  title: l10n.advancedSettingInletGasPressure,
                  hint: l10n.advancedSettingEnterInletGasPressure,
                  displayValue: v.inletGasPressureThreshold.round(),
                  displayMin: 0,
                  displayMax: 200,
                  signed: false,
                  onCommitDisplay: (n) => unawaited(
                    commit(
                      AdvancedSettingsModbusIds.inletGasPressureThreshold,
                      v.copyWith(inletGasPressureThreshold: n.toDouble()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SettingsSectionHeader(
            l10n.advancedSettingsGroupTemperatureThresholds,
            topInset: 36,
          ),
          Padding(
            padding: _hPad,
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: l10n.advancedSettingMotorTempAlarmThreshold,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                value: v.motorTempAlarm,
                min: 0,
                max: 80,
                valueLabel: tempLabel(v.motorTempAlarm.round()),
                scaleMinText: tempScale(0),
                scaleMaxText: tempScale(80),
                onChanged: (n) =>
                    preview(v.copyWith(motorTempAlarm: n.roundToDouble())),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.motorTempAlarmThreshold,
                    v.copyWith(motorTempAlarm: n.roundToDouble()),
                  ),
                ),
                onValueTap: () => unawaited(
                  editTempCelsius(
                    title: l10n.advancedSettingMotorTempAlarmThreshold,
                    hint: l10n.advancedSettingEnterMotorTempAlarmThreshold,
                    celsius: v.motorTempAlarm.round(),
                    minC: 0,
                    maxC: 80,
                    onCommitC: (c) => commit(
                      AdvancedSettingsModbusIds.motorTempAlarmThreshold,
                      v.copyWith(motorTempAlarm: c.toDouble()),
                    ),
                  ),
                ),
              ),
              right: SettingsScaledParam(
                title: l10n.advancedSettingDriverTempAlarmThreshold,
                borderGradientCenter:
                    CyberBorderGradientCenter.bottomLeftTopRight,
                value: v.driverTempAlarm,
                min: 0,
                max: 80,
                valueLabel: tempLabel(v.driverTempAlarm.round()),
                scaleMinText: tempScale(0),
                scaleMaxText: tempScale(80),
                onChanged: (n) =>
                    preview(v.copyWith(driverTempAlarm: n.roundToDouble())),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.driverTempAlarmThreshold,
                    v.copyWith(driverTempAlarm: n.roundToDouble()),
                  ),
                ),
                onValueTap: () => unawaited(
                  editTempCelsius(
                    title: l10n.advancedSettingDriverTempAlarmThreshold,
                    hint: l10n.advancedSettingEnterDriverTempAlarmThreshold,
                    celsius: v.driverTempAlarm.round(),
                    minC: 0,
                    maxC: 80,
                    onCommitC: (c) => commit(
                      AdvancedSettingsModbusIds.driverTempAlarmThreshold,
                      v.copyWith(driverTempAlarm: c.toDouble()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _cardGap,
          Padding(
            padding: _hPad,
            child: SettingsParamRow(
              left: SettingsScaledParam(
                title: l10n.advancedSettingProtectiveLensTempAlarmThreshold,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                value: v.protectiveLensTempAlarm,
                min: 0,
                max: 85,
                valueLabel: tempLabel(v.protectiveLensTempAlarm.round()),
                scaleMinText: tempScale(0),
                scaleMaxText: tempScale(85),
                onChanged: (n) => preview(
                  v.copyWith(protectiveLensTempAlarm: n.roundToDouble()),
                ),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold,
                    v.copyWith(protectiveLensTempAlarm: n.roundToDouble()),
                  ),
                ),
                onValueTap: () => unawaited(
                  editTempCelsius(
                    title: l10n.advancedSettingProtectiveLensTempAlarmThreshold,
                    hint: l10n
                        .advancedSettingEnterProtectiveLensTempAlarmThreshold,
                    celsius: v.protectiveLensTempAlarm.round(),
                    minC: 0,
                    maxC: 85,
                    onCommitC: (c) => commit(
                      AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold,
                      v.copyWith(protectiveLensTempAlarm: c.toDouble()),
                    ),
                  ),
                ),
              ),
              right: SettingsScaledParam(
                title: l10n.advancedSettingCollimatingLensTempAlarmThreshold,
                borderGradientCenter:
                    CyberBorderGradientCenter.bottomLeftTopRight,
                value: v.collimatingLensTempAlarm,
                min: 0,
                max: 85,
                valueLabel: tempLabel(v.collimatingLensTempAlarm.round()),
                scaleMinText: tempScale(0),
                scaleMaxText: tempScale(85),
                onChanged: (n) => preview(
                  v.copyWith(collimatingLensTempAlarm: n.roundToDouble()),
                ),
                onChangeEnd: (n) => unawaited(
                  commit(
                    AdvancedSettingsModbusIds.collimatingLensTempAlarmThreshold,
                    v.copyWith(collimatingLensTempAlarm: n.roundToDouble()),
                  ),
                ),
                onValueTap: () => unawaited(
                  editTempCelsius(
                    title: l10n.advancedSettingCollimatingLensTempAlarmThreshold,
                    hint: l10n
                        .advancedSettingEnterCollimatingLensTempAlarmThreshold,
                    celsius: v.collimatingLensTempAlarm.round(),
                    minC: 0,
                    maxC: 85,
                    onCommitC: (c) => commit(
                      AdvancedSettingsModbusIds
                          .collimatingLensTempAlarmThreshold,
                      v.copyWith(collimatingLensTempAlarm: c.toDouble()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _cardGap,
          Padding(
            padding: _hPad,
            child: SettingsScaledParam(
              title: l10n.advancedSettingTempAlarmRecoveryHysteresis,
              borderGradientCenter: CyberBorderGradientCenter.topBottom,
              value: v.tempAlarmRecoveryInterval,
              min: 0,
              max: 20,
              valueLabel: tempLabel(v.tempAlarmRecoveryInterval.round()),
              scaleMinText: tempScale(0),
              scaleMaxText: tempScale(20),
              onChanged: (n) => preview(
                v.copyWith(tempAlarmRecoveryInterval: n.roundToDouble()),
              ),
              onChangeEnd: (n) => unawaited(
                commit(
                  AdvancedSettingsModbusIds.tempAlarmRecoveryInterval,
                  v.copyWith(tempAlarmRecoveryInterval: n.roundToDouble()),
                ),
              ),
              onValueTap: () => unawaited(
                editTempCelsius(
                  title: l10n.advancedSettingTempAlarmRecoveryHysteresis,
                  hint: l10n.advancedSettingEnterTempAlarmRecoveryHysteresis,
                  celsius: v.tempAlarmRecoveryInterval.round(),
                  minC: 0,
                  maxC: 20,
                  onCommitC: (c) => commit(
                    AdvancedSettingsModbusIds.tempAlarmRecoveryInterval,
                    v.copyWith(tempAlarmRecoveryInterval: c.toDouble()),
                  ),
                ),
              ),
            ),
          ),
          SettingsSectionHeader(
            l10n.advancedSettingsGroupAiAssistance,
            topInset: 36,
          ),
          SettingsGroup(
            bottomInset: 0,
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSwitchRow(
                title: l10n.advancedSettingLensContaminationDetection,
                subtitle: l10n.advancedSettingLensContaminationDetectionHint,
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
                value: ai?.lensContaminationDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (x) => unawaited(
                          ai.setLensContaminationDetectionEnabled(x),
                        ),
              ),
              SettingsSwitchRow(
                title: l10n.advancedSettingZeroPointOffsetDetection,
                subtitle: l10n.advancedSettingZeroPointOffsetDetectionHint,
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
                value: ai?.zeroPointOffsetDetectionEnabled ?? true,
                onChanged: ai == null
                    ? null
                    : (x) => unawaited(
                          ai.setZeroPointOffsetDetectionEnabled(x),
                        ),
              ),
            ],
          ),
          SettingsSectionHeader(
            l10n.advancedSettingsGroupDangerousOperations,
            topInset: 36,
          ),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsSwitchRow(
                title: l10n.advancedSettingKeepLaserOnWhileAlarmed,
                subtitle: l10n.advancedSettingKeepLaserOnWhileAlarmedHint,
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
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
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
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
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
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
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
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
                titleFontSize: SettingsDimens.advancedSwitchTitleSize,
                subtitleFontSize: SettingsDimens.advancedSwitchSubtitleSize,
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
      if (common != null) common,
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
