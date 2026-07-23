package com.lasercyber.lws.ui.activitys.setting.ui;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerDataCheck;
import com.lasercyber.lws.ui.bean.ui.DataCheckResult;
import com.lasercyber.lws.ui.common.utils.TemperatureUnitConvertUtil;

public class AdvancedSettingDataCheck {
    private static DataCheckResult checkIntegerRange(
            String data,
            int min,
            int max,
            int emptyMessage,
            int formatMessage,
            int minMessage,
            int maxMessage
    ) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(emptyMessage);
            return DataCheckResult.fail();
        }
        int intValue;
        try {
            intValue = Integer.parseInt(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(formatMessage);
            return DataCheckResult.fail();
        }
        if (intValue < min) {
            ToastUtils.showShort(minMessage);
            return DataCheckResult.fail();
        }
        if (intValue > max) {
            ToastUtils.showShort(maxMessage);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验零点较正
     *
     * @param data
     * @return
     */
    public static DataCheckResult checkZeroPointCorrection(String data) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.zero_offset_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.zero_offset_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < -30) {
            ToastUtils.showShort(R.string.zero_offset_cannot_be_less_than);
            return DataCheckResult.fail();
        }
        if (intValue > 30) {
            ToastUtils.showShort(R.string.zero_offset_cannot_be_greater_than);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    public static DataCheckResult checkScanWidthCorrection(String data) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.scan_width_correction_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.scan_width_correction_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < -75) {
            ToastUtils.showShort(R.string.the_scan_width_correction_cannot_be_less_than);
            return DataCheckResult.fail();
        }
        if (intValue > 75) {
            ToastUtils.showShort(R.string.the_scan_width_correction_cannot_exceed);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验起始功率
     *
     * @param data
     * @return
     */
    public static DataCheckResult checkLaserStartingPower(String data) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.laser_starting_power_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.laser_starting_power_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.the_laser_starting_power_cannot_be_less_than);
            return DataCheckResult.fail();
        }
        if (intValue > 100) {
            ToastUtils.showShort(R.string.the_laser_starting_power_cannot_exceed);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 激光终止功率
     *
     * @param data
     * @return
     */
    public static DataCheckResult checkLaserTerminationPower(String data) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.laser_termination_power_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.laser_termination_power_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.the_laser_termination_power_cannot_be_less_than);
            return DataCheckResult.fail();
        }
        if (intValue > 100) {
            ToastUtils.showShort(R.string.the_laser_termination_power_cannot_exceed);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * Gas Pressure Threshold
     *
     * @param data
     * @return
     */
    public static DataCheckResult checkGasPressureThreshold(String data) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.gas_pressure_threshold_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.gas_pressure_threshold_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.the_gas_pressure_threshold_cannot_be_less_than);
            return DataCheckResult.fail();
        }
        if (intValue > 400) {
            ToastUtils.showShort(R.string.the_gas_pressure_threshold_cannot_exceed);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    public static DataCheckResult checkInletGasPressureThreshold(String data) {
        return checkIntegerRange(
                data,
                0,
                200,
                R.string.inlet_gas_pressure_threshold_cannot_be_empty,
                R.string.inlet_gas_pressure_threshold_format_error,
                R.string.the_inlet_gas_pressure_threshold_cannot_be_less_than,
                R.string.the_inlet_gas_pressure_threshold_cannot_exceed
        );
    }

    public static DataCheckResult checkDriverTemperatureAlarmThreshold(String data, Boolean unitSetting) {
        return checkTemperatureRange(
                data,
                unitSetting,
                0,
                80,
                R.string.driver_temperature_alarm_threshold_cannot_be_empty,
                R.string.driver_temperature_alarm_threshold_format_error,
                R.string.the_driver_temperature_alarm_threshold_cannot_be_less_than,
                R.string.the_driver_temperature_alarm_threshold_cannot_exceed
        );
    }

    public static DataCheckResult checkProtectiveLensTemperatureAlarmThreshold(String data, Boolean unitSetting) {
        return checkTemperatureRange(
                data,
                unitSetting,
                0,
                85,
                R.string.protective_lens_temperature_alarm_threshold_cannot_be_empty,
                R.string.protective_lens_temperature_alarm_threshold_format_error,
                R.string.the_protective_lens_temperature_alarm_threshold_cannot_be_less_than,
                R.string.the_protective_lens_temperature_alarm_threshold_cannot_exceed
        );
    }

    public static DataCheckResult checkCollimatingLensTemperatureAlarmThreshold(String data, Boolean unitSetting) {
        return checkTemperatureRange(
                data,
                unitSetting,
                0,
                85,
                R.string.collimating_lens_temperature_alarm_threshold_cannot_be_empty,
                R.string.collimating_lens_temperature_alarm_threshold_format_error,
                R.string.the_collimating_lens_temperature_alarm_threshold_cannot_be_less_than,
                R.string.the_collimating_lens_temperature_alarm_threshold_cannot_exceed
        );
    }

    public static DataCheckResult checkMotorTemperatureAlarmThreshold(String data, Boolean unitSetting) {
        return checkTemperatureRange(
                data,
                unitSetting,
                0,
                80,
                R.string.motor_temperature_alarm_threshold_cannot_be_empty,
                R.string.motor_temperature_alarm_threshold_format_error,
                R.string.the_motor_temperature_alarm_threshold_cannot_be_less_than,
                R.string.the_motor_temperature_alarm_threshold_cannot_exceed
        );
    }

    public static DataCheckResult checkTemperatureAlarmRecoveryInterval(String data, Boolean unitSetting) {
        return checkTemperatureRange(
                data,
                unitSetting,
                0,
                20,
                R.string.temperature_alarm_recovery_interval_cannot_be_empty,
                R.string.temperature_alarm_recovery_interval_format_error,
                R.string.the_temperature_alarm_recovery_interval_cannot_be_less_than,
                R.string.the_temperature_alarm_recovery_interval_cannot_exceed
        );
    }

    private static DataCheckResult checkTemperatureRange(
            String data,
            Boolean unitSetting,
            int minCelsius,
            int maxCelsius,
            int emptyMessage,
            int formatMessage,
            int minMessage,
            int maxMessage
    ) {
        String value = EngineerDataCheck.convertData(data, "");
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(emptyMessage);
            return DataCheckResult.fail();
        }
        try {
            value = TemperatureUnitConvertUtil.parseInputToCelsiusString(value, unitSetting);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(formatMessage);
            return DataCheckResult.fail();
        }
        return checkIntegerRange(value, minCelsius, maxCelsius, emptyMessage, formatMessage, minMessage, maxMessage);
    }
}
