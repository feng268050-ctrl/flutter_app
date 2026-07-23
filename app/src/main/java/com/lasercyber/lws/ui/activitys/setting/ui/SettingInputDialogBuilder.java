package com.lasercyber.lws.ui.activitys.setting.ui;

import android.app.Activity;
import android.content.Context;

import com.blankj.utilcode.util.ActivityUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.setting.model.AdvancedSettingViewModel;
import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;
import com.lasercyber.lws.ui.bean.ui.DataCheckResult;
import com.lasercyber.lws.ui.common.utils.TemperatureUnitConvertUtil;
import com.lasercyber.lws.ui.component.dialog.FrostNumericInputDialog;

import java.util.function.Consumer;

/**
 * 告警设置的输入弹窗构建者
 */
public class SettingInputDialogBuilder {

    private static Context dialogContext() {
        Activity top = ActivityUtils.getTopActivity();
        return top != null ? top : Utils.getApp();
    }

    private static void showSignedInteger(
            int titleRes,
            String defaultInput,
            int minValue,
            int maxValue,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        FrostNumericInputDialog.show(
                dialogContext(),
                FrostNumericInputDialog.Config.builder(Utils.getApp().getString(titleRes))
                        .signedIntegerInput()
                        .minValue(minValue)
                        .maxValue(maxValue)
                        .defaultInput(defaultInput)
                        .build(),
                listener);
    }

    private static void showInteger(
            int titleRes,
            String defaultInput,
            int minValue,
            int maxValue,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        FrostNumericInputDialog.show(
                dialogContext(),
                FrostNumericInputDialog.Config.builder(Utils.getApp().getString(titleRes))
                        .integerNumberInput()
                        .minValue(minValue)
                        .maxValue(maxValue)
                        .defaultInput(defaultInput)
                        .build(),
                listener);
    }

    private static int displayTemperatureBound(int celsius, Boolean unitSetting) {
        return TemperatureUnitConvertUtil.isMetricUnit(unitSetting)
                ? celsius
                : TemperatureUnitConvertUtil.celsiusToFahrenheit(celsius);
    }

    public static void zeroPointCorrectionBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = data != null ? data.getZeroPointCorrection() : "";
        showSignedInteger(R.string.zero_point_correction_text, defaultText, -30, 30, inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkZeroPointCorrection(inputData);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setZeroPointCorrection(dataCheckResult.getData());
            }
            callBack.accept(inputData);
            return true;
        });
    }

    public static void scanWidthCorrectionBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = data != null ? data.getProperSwingWidth() : "";
        showSignedInteger(R.string.proper_swing_width_text, defaultText, -75, 75, inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkScanWidthCorrection(inputData);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setProperSwingWidth(dataCheckResult.getData());
            }
            callBack.accept(inputData);
            return true;
        });
    }

    public static void laserStartingPowerBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = data != null ? data.getLaserStartPower() : "";
        showInteger(R.string.laser_start_power_text, defaultText, 0, 100, inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkLaserStartingPower(inputData);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setLaserStartPower(dataCheckResult.getData());
            }
            callBack.accept(inputData);
            return true;
        });
    }

    public static void laserTerminationPowerBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = data != null ? data.getLaserEndPower() : "";
        showInteger(R.string.laser_end_power_text, defaultText, 0, 100, inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkLaserTerminationPower(inputData);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setLaserEndPower(dataCheckResult.getData());
            }
            callBack.accept(inputData);
            return true;
        });
    }

    public static void GasPressureThresholdBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = data != null ? data.getBlowPressureThreshold() : "";
        showInteger(R.string.blow_pressure_threshold_text, defaultText, 0, 400, inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkGasPressureThreshold(inputData);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setBlowPressureThreshold(dataCheckResult.getData());
            }
            callBack.accept(inputData);
            return true;
        });
    }

    public static void inletGasPressureThresholdBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = data != null ? data.getInletGasPressureThreshold() : "";
        showInteger(R.string.inlet_gas_pressure_threshold_text, defaultText, 0, 200, inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkInletGasPressureThreshold(inputData);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setInletGasPressureThreshold(dataCheckResult.getData());
            }
            callBack.accept(inputData);
            return true;
        });
    }

    public static void driverTemperatureAlarmThresholdBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = "";
        Boolean unitSetting = null;
        if (data != null) {
            defaultText = data.getDriverTemperatureAlarmThresholdDisplay();
            unitSetting = data.getUnitSetting();
        }
        Boolean finalUnitSetting = unitSetting;
        showInteger(
                R.string.driver_temperature_alarm_threshold_text,
                defaultText,
                displayTemperatureBound(0, finalUnitSetting),
                displayTemperatureBound(80, finalUnitSetting),
                inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkDriverTemperatureAlarmThreshold(
                    inputData, finalUnitSetting);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setDriverTemperatureAlarmThreshold(dataCheckResult.getData());
            }
            callBack.accept(dataCheckResult.getData());
            return true;
        });
    }

    public static void protectiveLensTemperatureAlarmThresholdBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = "";
        Boolean unitSetting = null;
        if (data != null) {
            defaultText = data.getProtectiveLensTemperatureAlarmThresholdDisplay();
            unitSetting = data.getUnitSetting();
        }
        Boolean finalUnitSetting = unitSetting;
        showInteger(
                R.string.protective_lens_temperature_alarm_threshold_text,
                defaultText,
                displayTemperatureBound(0, finalUnitSetting),
                displayTemperatureBound(85, finalUnitSetting),
                inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkProtectiveLensTemperatureAlarmThreshold(
                    inputData, finalUnitSetting);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setProtectiveLensTemperatureAlarmThreshold(dataCheckResult.getData());
            }
            callBack.accept(dataCheckResult.getData());
            return true;
        });
    }

    public static void collimatingLensTemperatureAlarmThresholdBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = "";
        Boolean unitSetting = null;
        if (data != null) {
            defaultText = data.getCollimatingLensTemperatureAlarmThresholdDisplay();
            unitSetting = data.getUnitSetting();
        }
        Boolean finalUnitSetting = unitSetting;
        showInteger(
                R.string.collimating_lens_temperature_alarm_threshold_text,
                defaultText,
                displayTemperatureBound(0, finalUnitSetting),
                displayTemperatureBound(85, finalUnitSetting),
                inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkCollimatingLensTemperatureAlarmThreshold(
                    inputData, finalUnitSetting);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setCollimatingLensTemperatureAlarmThreshold(dataCheckResult.getData());
            }
            callBack.accept(dataCheckResult.getData());
            return true;
        });
    }

    public static void motorTemperatureAlarmThresholdBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = "";
        Boolean unitSetting = null;
        if (data != null) {
            defaultText = data.getMotorTemperatureAlarmThresholdDisplay();
            unitSetting = data.getUnitSetting();
        }
        Boolean finalUnitSetting = unitSetting;
        showInteger(
                R.string.motor_temperature_alarm_threshold_text,
                defaultText,
                displayTemperatureBound(0, finalUnitSetting),
                displayTemperatureBound(80, finalUnitSetting),
                inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkMotorTemperatureAlarmThreshold(
                    inputData, finalUnitSetting);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setMotorTemperatureAlarmThreshold(dataCheckResult.getData());
            }
            callBack.accept(dataCheckResult.getData());
            return true;
        });
    }

    public static void temperatureAlarmRecoveryIntervalBuilder(
            AdvancedSettingViewModel advancedSettingViewModel,
            Consumer<String> callBack) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        String defaultText = "";
        Boolean unitSetting = null;
        if (data != null) {
            defaultText = data.getTemperatureAlarmRecoveryIntervalDisplay();
            unitSetting = data.getUnitSetting();
        }
        Boolean finalUnitSetting = unitSetting;
        showInteger(
                R.string.temperature_alarm_recovery_interval_text,
                defaultText,
                displayTemperatureBound(0, finalUnitSetting),
                displayTemperatureBound(20, finalUnitSetting),
                inputData -> {
            DataCheckResult dataCheckResult = AdvancedSettingDataCheck.checkTemperatureAlarmRecoveryInterval(
                    inputData, finalUnitSetting);
            if (!dataCheckResult.isSuccess()) {
                return false;
            }
            if (data != null) {
                data.setTemperatureAlarmRecoveryInterval(dataCheckResult.getData());
            }
            callBack.accept(dataCheckResult.getData());
            return true;
        });
    }
}
