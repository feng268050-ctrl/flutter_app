package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import androidx.lifecycle.LiveData;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.ProcessParametersDataViewModel;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.DataCheckResult;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.utils.InchMillimeterUtils;

/**
 * 工程师模式的字段校验
 */
public class EngineerDataCheck {
    /**
     * 提取数据
     *
     * @param data
     * @param unit
     * @return
     */
    public static String convertData(String data, String unit) {
        if (StringUtils.isEmpty(data)) {
            return null;
        }
        return data.replaceAll(unit, "").trim();
    }

    /**
     * 校验功率缓升
     * 单位: 10%~100%
     * 单位: %
     *
     * @param laserPower 数据
     * @return
     */
    public static DataCheckResult weldingPowerCheck(String laserPower, Double startPower) {
        String value = convertData(laserPower, Utils.getApp().getString(R.string.percentage_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.laser_power_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue = Double.parseDouble(value);
        if (intValue < 0) {
            ToastUtils.showShort(R.string.the_laser_power_must_be_greater_than_zero);
            return DataCheckResult.fail();
        }
        if (intValue <= startPower) {
            ToastUtils.showShort(R.string.the_laser_power_must_be_greater_than_the_starting_power);
            return DataCheckResult.fail();
        }
        if (intValue > 100) {
            ToastUtils.showShort(R.string.laser_power_cannot_exceed_100);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验激光终止功率
     *
     * @param laserPower
     * @param endPower
     * @return
     */
    public static boolean checkLaserEndPower(String laserPower, Double endPower) {
        String value = convertData(laserPower, Utils.getApp().getString(R.string.percentage_unit));
        double intValue = Double.parseDouble(value);
        if (intValue < endPower) {
            ToastUtils.showShort("The laser power cannot be less than the termination power");
            return false;
        }
        return true;
    }
    /**
     * 校验穿孔功率（0~100%）
     *
     * @param perforationPower 数据
     * @return
     */
    public static DataCheckResult perforationPowerCheck(String perforationPower) {
        String value = convertData(perforationPower, Utils.getApp().getString(R.string.percentage_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.perforation_power_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.perforation_power_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.perforation_power_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 100) {
            ToastUtils.showShort(R.string.perforation_power_cannot_exceed_100);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验摆动频率（清洗：20~200Hz；焊接：0~220Hz）
     *
     * @param swingFrequency 数据
     * @param processType    工艺类型（参考ModelConstant）
     * @return
     */
    public static DataCheckResult swingFrequencyCheck(String swingFrequency, int processType) {
        String hzUnit = Utils.getApp().getString(R.string.hz_unit);
        String value = convertData(swingFrequency, hzUnit);
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.swing_frequency_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.swing_frequency_format_error);
            return DataCheckResult.fail();
        }
        // 需根据ModelConstant中工艺类型的实际值判断
//        if (processType == ModelConstant.WELD_CLEAN||processType == ModelConstant.WIDTH_CLEAN) { // 清洗
//            if (intValue < 20) {
//                ToastUtils.showShort(R.string.clean_swing_frequency_cannot_be_less_than_20);
//                return DataCheckResult.fail();
//            }
//            if (intValue > 200) {
//                ToastUtils.showShort(R.string.clean_swing_frequency_cannot_exceed_200);
//                return DataCheckResult.fail();
//            }
//        } else if (processType == ModelConstant.CONTINUOUS_WELDING||processType == ModelConstant.POINT_WELDING) { // 焊接
        boolean isPointWelding = processType == ModelConstant.POINT_WELDING;
        if (isPointWelding && intValue == 0) {
            return DataCheckResult.success(value);
        }
        if (intValue < 20) {
            ToastUtils.showShort(Utils.getApp().getString(R.string.weld_swing_frequency_cannot_be_less_than_0) + hzUnit);
            return DataCheckResult.fail();
        }
        if (intValue > 220) {
            ToastUtils.showShort(R.string.weld_swing_frequency_cannot_exceed_220);
            return DataCheckResult.fail();
        }
//        } else {
//            ToastUtils.showShort(R.string.unknown_process_type);
//            return DataCheckResult.fail();
//        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验激光频率（1~5000Hz）
     *
     * @param laserFrequency 数据
     * @return
     */
    public static DataCheckResult laserFrequencyCheck(String laserFrequency) {
        String value = convertData(laserFrequency, Utils.getApp().getString(R.string.hz_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.laser_frequency_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.laser_frequency_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 1) {
            ToastUtils.showShort(R.string.laser_frequency_cannot_be_less_than_1);
            return DataCheckResult.fail();
        }
        if (intValue > 5000) {
            ToastUtils.showShort(R.string.laser_frequency_cannot_exceed_5000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验穿孔频率（0~2000Hz）
     *
     * @param perforationFrequency 数据
     * @return
     */
    public static DataCheckResult perforationFrequencyCheck(String perforationFrequency) {
        String value = convertData(perforationFrequency, Utils.getApp().getString(R.string.hz_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.perforation_frequency_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.perforation_frequency_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.perforation_frequency_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 2000) {
            ToastUtils.showShort(R.string.perforation_frequency_cannot_exceed_2000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 摆动宽度上限（mm）：宽幅清洗 0~30，其它模式 0~6。
     */
    public static double swingWidthMaxMm(int processType) {
        return processType == ModelConstant.WIDTH_CLEAN ? 30d : 6d;
    }

    /**
     * 校验摆动宽度（宽幅清洗：0~30mm；其它：0~6mm）
     *
     * @param swingWidth  数据
     * @param processType 工艺类型（参考 ModelConstant）
     */
    public static DataCheckResult swingWidthCheck(String swingWidth, boolean useMMUnit, int processType) {
        String value = convertData(swingWidth, Utils.getApp().getString(useMMUnit ? R.string.mm_unit : R.string.in_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.swing_width_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.swing_width_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.swing_width_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        double maxMm = swingWidthMaxMm(processType);
        double maxValue = useMMUnit ? maxMm : InchMillimeterUtils.mmToIn(maxMm);
        if (intValue > maxValue) {
            String text = Utils.getApp().getString(R.string.swing_width_cannot_exceed_6) + maxValue;
            ToastUtils.showShort(text);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验吹气延时（0~10000ms）
     *
     * @param blowDelay 数据
     * @return
     */
    public static DataCheckResult blowDelayCheck(String blowDelay) {
        String value = convertData(blowDelay, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.blow_delay_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.blow_delay_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.blow_delay_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 10000) {
            ToastUtils.showShort(R.string.blow_delay_cannot_exceed_10000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验关气延时（0~10000ms）
     *
     * @param closeAirDelay 数据
     * @return
     */
    public static DataCheckResult closeAirDelayCheck(String closeAirDelay) {
        String value = convertData(closeAirDelay, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.close_air_delay_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.close_air_delay_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.close_air_delay_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 10000) {
            ToastUtils.showShort(R.string.close_air_delay_cannot_exceed_10000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验关光延时（0~1000ms）
     *
     * @param closeLightDelay 数据
     * @return
     */
    public static DataCheckResult closeLightDelayCheck(String closeLightDelay) {
        String value = convertData(closeLightDelay, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.close_light_delay_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.close_light_delay_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.close_light_delay_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 1000) {
            ToastUtils.showShort(R.string.close_light_delay_cannot_exceed_1000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验补丝时延（0~1000ms）
     *
     * @param fillDelay 数据
     * @return
     */
    public static DataCheckResult fillDelayCheck(String fillDelay) {
        String value = convertData(fillDelay, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.fill_delay_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.fill_delay_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.fill_delay_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 1000) {
            ToastUtils.showShort(R.string.fill_delay_cannot_exceed_1000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验送丝时延（0~2000ms）
     *
     * @param wireFeedingDelay 数据
     * @return
     */
    public static DataCheckResult wireFeedingDelayCheck(String wireFeedingDelay) {
        String value = convertData(wireFeedingDelay, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.wire_feeding_delay_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.wire_feeding_delay_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.wire_feeding_delay_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 2000) {
            ToastUtils.showShort(R.string.wire_feeding_delay_cannot_exceed_2000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验穿孔时长(0.1~2.0s)
     *
     * @param perforationDuration 数据
     * @return
     */
    public static DataCheckResult perforationDurationCheck(String perforationDuration) {
        String value = convertData(perforationDuration, Utils.getApp().getString(R.string.s_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.perforation_duration_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double doubleValue;
        try {
            doubleValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.perforation_duration_format_error);
            return DataCheckResult.fail();
        }
        if (doubleValue < 0.1) {
            ToastUtils.showShort(R.string.perforation_duration_cannot_be_less_than_0_1);
            return DataCheckResult.fail();
        }
        if (doubleValue > 2.0) {
            ToastUtils.showShort(R.string.perforation_duration_cannot_exceed_2_0);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验点焊间隔（0~10000ms）
     *
     * @param pointWeldingInterval 数据
     * @return
     */
    public static DataCheckResult pointWeldingIntervalCheck(String pointWeldingInterval) {
        String value = convertData(pointWeldingInterval, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.point_welding_interval_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.point_welding_interval_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.point_welding_interval_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 10000) {
            ToastUtils.showShort(R.string.point_welding_interval_cannot_exceed_10000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验点焊持续（0~10000ms）
     *
     * @param pointWeldingDuration 数据
     * @return
     */
    public static DataCheckResult pointWeldingDurationCheck(String pointWeldingDuration) {
        String value = convertData(pointWeldingDuration, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.point_welding_duration_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.point_welding_duration_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.point_welding_duration_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 10000) {
            ToastUtils.showShort(R.string.point_welding_duration_cannot_exceed_10000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验功率缓升（0~1000ms）
     *
     * @param powerRampUp 数据
     * @return
     */
    public static DataCheckResult powerRampUpCheck(String powerRampUp) {
        String value = convertData(powerRampUp, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.power_ramp_up_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.power_ramp_up_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.power_ramp_up_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 1000) {
            ToastUtils.showShort(R.string.power_ramp_up_cannot_exceed_1000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验功率缓降（0~1000ms）
     *
     * @param powerRampDown 数据
     * @return
     */
    public static DataCheckResult powerRampDownCheck(String powerRampDown) {
        String value = convertData(powerRampDown, Utils.getApp().getString(R.string.ms_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.power_ramp_down_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.power_ramp_down_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.power_ramp_down_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 1000) {
            ToastUtils.showShort(R.string.power_ramp_down_cannot_exceed_1000);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验送丝速度（0~50mm/s）
     *
     * @param wireFeedSpeed 数据
     * @return
     */
    public static DataCheckResult wireFeedSpeedCheck(String wireFeedSpeed, boolean useMMUnit) {
        String value = convertData(wireFeedSpeed, Utils.getApp().getString(useMMUnit ? R.string.mm_s_unit : R.string.in_s_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.wire_feed_speed_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.wire_feed_speed_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.wire_feed_speed_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        double maxValue = useMMUnit ? 50 : InchMillimeterUtils.mmToInPerSecond(50d);
        if (intValue > maxValue) {
            String text = Utils.getApp().getString(R.string.wire_feed_speed_cannot_exceed_50) + maxValue;
            ToastUtils.showShort(text);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验回抽长度（0~35mm）
     *
     * @param retractLength 数据
     * @return
     */
    public static DataCheckResult retractLengthCheck(String retractLength, boolean useMMUnit) {
        String value = convertData(retractLength, Utils.getApp().getString(useMMUnit ? R.string.mm_unit : R.string.in_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.retract_length_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.retract_length_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.retract_length_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        double maxValue = useMMUnit ? 35 : InchMillimeterUtils.mmToIn(35d);
        if (intValue > maxValue) {
            String text = Utils.getApp().getString(R.string.retract_length_cannot_exceed_15) + maxValue;
            ToastUtils.showShort(text);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验回抽速度（3~100mm/s）
     *
     * @param retractSpeed 数据
     * @return
     */
    public static DataCheckResult retractSpeedCheck(String retractSpeed, boolean useMMUnit) {
        String value = convertData(retractSpeed, Utils.getApp().getString(useMMUnit ? R.string.mm_s_unit : R.string.in_s_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.retract_speed_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.retract_speed_format_error);
            return DataCheckResult.fail();
        }
        double minValue = useMMUnit ? 3 : InchMillimeterUtils.mmToInPerSecond(3);
        if (intValue < 3) {
            String text = Utils.getApp().getString(R.string.retract_speed_cannot_be_less_than_0) + minValue;
            ToastUtils.showShort(text);
            return DataCheckResult.fail();
        }
        double maxValue = useMMUnit ? 100 : InchMillimeterUtils.mmToInPerSecond(100d);
        if (intValue > maxValue) {
            String text = Utils.getApp().getString(R.string.retract_speed_cannot_exceed_300) + maxValue;
            ToastUtils.showShort(text);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验补丝长度（0~35mm）
     *
     * @param fillLength 数据
     * @return
     */
    public static DataCheckResult fillLengthCheck(String fillLength, boolean useMMUnit) {
        String value = convertData(fillLength, Utils.getApp().getString(useMMUnit ? R.string.mm_unit : R.string.in_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.fill_length_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.fill_length_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.fill_length_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        double maxValue = useMMUnit ? 35 : InchMillimeterUtils.mmToIn(35d);
        if (intValue > maxValue) {
            String text = Utils.getApp().getString(R.string.fill_length_cannot_exceed_15) + maxValue;
            ToastUtils.showShort(text);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验激光占空比（0~100%）
     *
     * @param laserDutyCycle 数据
     * @return
     */
    public static DataCheckResult laserDutyCycleCheck(String laserDutyCycle) {
        String value = convertData(laserDutyCycle, Utils.getApp().getString(R.string.percentage_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.laser_duty_cycle_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.laser_duty_cycle_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 1) {
            ToastUtils.showShort(R.string.laser_duty_cycle_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 100) {
            ToastUtils.showShort(R.string.laser_duty_cycle_cannot_exceed_100);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验穿孔占空比（0~100%）
     *
     * @param perforationDutyCycle 数据
     * @return
     */
    public static DataCheckResult perforationDutyCycleCheck(String perforationDutyCycle) {
        String value = convertData(perforationDutyCycle, Utils.getApp().getString(R.string.percentage_unit));
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.perforation_duty_cycle_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double intValue;
        try {
            intValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.perforation_duty_cycle_format_error);
            return DataCheckResult.fail();
        }
        if (intValue < 0) {
            ToastUtils.showShort(R.string.perforation_duty_cycle_cannot_be_less_than_0);
            return DataCheckResult.fail();
        }
        if (intValue > 100) {
            ToastUtils.showShort(R.string.perforation_duty_cycle_cannot_exceed_100);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(value);
    }

    /**
     * 校验厚度（无明确范围定义，需补充业务规则）
     *
     * @param thickness 数据
     * @return
     */
    public static DataCheckResult thicknessCheck(String thickness, boolean useMMUnit) {
        String unit = Utils.getApp().getString(useMMUnit ? R.string.mm_unit : R.string.in_unit);
        String value = convertData(thickness, unit); // 假设单位为mm
        if (StringUtils.isEmpty(value)) {
            ToastUtils.showShort(R.string.thickness_cannot_be_empty);
            return DataCheckResult.fail();
        }
        double doubleValue = 0;
        try {
            doubleValue = Double.parseDouble(value);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.thickness_format_error);
            return DataCheckResult.fail();
        }
        double minValue = useMMUnit ? 1 : InchMillimeterUtils.mmToIn(1);
        if (doubleValue < minValue) {
            String errorText = Utils.getApp().getString(R.string.the_materials_thickness_must_be_greater_than) + minValue + unit;
            ToastUtils.showShort(errorText);
            return DataCheckResult.fail();
        }
        double maxValue = useMMUnit ? 8 : InchMillimeterUtils.mmToIn(8);
        if (doubleValue > maxValue) {
            String errorText = Utils.getApp().getString(R.string.the_materials_thickness_must_be_less_than) + maxValue + unit;
            ToastUtils.showShort(errorText);
            return DataCheckResult.fail();
        }
        // 此处需根据实际业务规则补充数值范围校验
        return DataCheckResult.success(value);
    }

    /**
     * 校验材料（无明确范围定义，需补充业务规则）
     *
     * @param materials 数据
     * @return
     */
    public static DataCheckResult materialsCheck(String materials) {
        if (StringUtils.isEmpty(materials)) {
            ToastUtils.showShort(R.string.materials_cannot_be_empty);
            return DataCheckResult.fail();
        }
        try {
            Double.parseDouble(materials);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.materials_format_error);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(materials);
    }

    /**
     * 校验参数名称（无明确规则，需补充业务规则）
     *
     * @param name 数据
     * @return
     */
    public static DataCheckResult nameCheck(String name) {
        if (StringUtils.isEmpty(name)) {
            ToastUtils.showShort(R.string.params_name_cannot_be_empty);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(name);
    }

    /**
     * 校验工艺类型（需结合ModelConstant定义）
     *
     * @param processType 数据
     * @return
     */
    public static DataCheckResult processTypeCheck(String processType) {
        if (StringUtils.isEmpty(processType)) {
            ToastUtils.showShort(R.string.process_type_cannot_be_empty);
            return DataCheckResult.fail();
        }
        try {
            Double.parseDouble(processType);
        } catch (NumberFormatException e) {
            ToastUtils.showShort(R.string.process_type_format_error);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(processType);
    }

    /**
     * 校验材质名称
     *
     * @param inputData
     * @return
     */
    public static DataCheckResult materialCheck(String inputData) {
        if (StringUtils.isEmpty(inputData)) {
            ToastUtils.showShort(R.string.material_name_cannot_empty);
            return DataCheckResult.fail();
        }
        if (inputData.length() > 20) {
            ToastUtils.showShort(R.string.material_name_cannot_exceed_characters);
            return DataCheckResult.fail();
        }
        return DataCheckResult.success(inputData);
    }

    /**
     * 校验激光功率
     *
     * @param processParametersData
     * @param advancedSetting
     * @return
     */
    public static boolean checkLaserPower(ProcessParametersData processParametersData, AdvancedSettings parameterSettings) {
        if (processParametersData == null || processParametersData.getLaserPower() == null) {
            ToastUtils.showShort(R.string.laser_power_cannot_be_empty);
            return false;
        }
        if (parameterSettings == null) {
            return true;
        }
        if (parameterSettings.getLaserStartPower() != null && processParametersData.getLaserPower() <= parameterSettings.getLaserStartPower()) {
            ToastUtils.showShort(R.string.the_laser_power_must_exceed_the_laser_starting_power);
            return false;
        }
        if (parameterSettings.getLaserEndPower() != null && processParametersData.getLaserPower() <= parameterSettings.getLaserEndPower()) {
            ToastUtils.showShort(R.string.the_laser_power_must_be_less_than_the_laser_end_power);
            return false;
        }
        return true;
    }

    /**
     * 校验焊接下发的参数
     *
     * @param processParametersDataViewModel
     * @return
     */
    public static boolean checkWeldingSendProcessParametersData(ProcessParametersDataViewModel processParametersDataViewModel) {
        if (!checkBaseSendProcessParametersData(processParametersDataViewModel)) {
            ToastUtils.showShort(R.string.parameter_exception_text);
            return false;
        }
        if (processParametersDataViewModel.getType() == ModelConstant.POINT_WELDING) {
            // 点焊间隔
            if (!EngineerDataCheck.pointWeldingIntervalCheck(processParametersDataViewModel.getPointWeldingInterval()).isSuccess()) {
                return false;
            }
            // 点焊持续
            if (!EngineerDataCheck.pointWeldingDurationCheck(processParametersDataViewModel.getPointWeldingDuration()).isSuccess()) {
                return false;
            }
        }
        // 吹气延时
        if (!EngineerDataCheck.blowDelayCheck(processParametersDataViewModel.getBlowDelay()).isSuccess()) {
            return false;
        }
        if (processParametersDataViewModel.getType() == ModelConstant.CONTINUOUS_WELDING) {
            // 功率缓升
            if (!EngineerDataCheck.powerRampUpCheck(processParametersDataViewModel.getPowerRampUp()).isSuccess()) {
                return false;
            }
        }
        // 焊接功率
        if (!EngineerDataCheck.weldingPowerCheck(processParametersDataViewModel.getLaserPower(), processParametersDataViewModel.getStartPower()).isSuccess()) {
            return false;
        }
        if (!EngineerDataCheck.checkLaserPower(processParametersDataViewModel.getData(), processParametersDataViewModel.getAdvancedSetting())) {
            return false;
        }
        if (processParametersDataViewModel.getType() == ModelConstant.CONTINUOUS_WELDING) {
            // 功率缓降
            if (!EngineerDataCheck.powerRampDownCheck(processParametersDataViewModel.getPowerRampDown()).isSuccess()) {
                return false;
            }
        }
        // 关气延时
        if (!EngineerDataCheck.closeAirDelayCheck(processParametersDataViewModel.getCloseAirDelay()).isSuccess()) {
            return false;
        }
        // 摆动频率
        if (!EngineerDataCheck.swingFrequencyCheck(processParametersDataViewModel.getSwingFrequency(), processParametersDataViewModel.getType()).isSuccess()) {
            return false;
        }
        // 焊接宽度
        if (!EngineerDataCheck.swingWidthCheck(
                processParametersDataViewModel.getSwingWidth(),
                processParametersDataViewModel.useMMUnit(),
                java.util.Objects.requireNonNullElse(
                        processParametersDataViewModel.getType(), ModelConstant.CONTINUOUS_WELDING)).isSuccess()) {
            return false;
        }
        // 送丝速度（点焊模式不需要送丝，跳过校验）
        if (processParametersDataViewModel.getType() != ModelConstant.POINT_WELDING) {
            if (!EngineerDataCheck.wireFeedSpeedCheck(
                    processParametersDataViewModel.getWireFeedSpeed(),
                    processParametersDataViewModel.useMMUnit()).isSuccess()) {
                return false;
            }
        }
        // 关光延时
        if (!EngineerDataCheck.closeLightDelayCheck(processParametersDataViewModel.getCloseLightDelay()).isSuccess()) {
            return false;
        }
        if (processParametersDataViewModel.getType() == ModelConstant.CONTINUOUS_WELDING) {
            // 回抽长度
            if (!EngineerDataCheck.retractLengthCheck(processParametersDataViewModel.getRetractLength(), processParametersDataViewModel.useMMUnit()).isSuccess()) {
                return false;
            }
            // 回抽速度
            if (!EngineerDataCheck.retractSpeedCheck(
                    processParametersDataViewModel.getRetractSpeed(),
                    processParametersDataViewModel.useMMUnit()).isSuccess()) {
                return false;
            }
            // 补丝长度
            if (!EngineerDataCheck.fillLengthCheck(processParametersDataViewModel.getFillLength(), processParametersDataViewModel.useMMUnit()).isSuccess()) {
                return false;
            }
            // 补丝延时
            if (!EngineerDataCheck.fillDelayCheck(processParametersDataViewModel.getFillDelay()).isSuccess()) {
                return false;
            }
        }
        return true;
    }

    private static boolean checkBaseSendProcessParametersData(ProcessParametersDataViewModel processParametersDataViewModel) {
        if (processParametersDataViewModel == null) {
            return false;
        }
        LiveData<ProcessParametersData> liveData = processParametersDataViewModel.getLiveData();
        if (liveData == null) {
            return false;
        }
        ProcessParametersData processParametersData = liveData.getValue();
        if (processParametersData == null) {
            return false;
        }
        return true;
    }

    /**
     * 校清洗接下发的参数
     *
     * @param processParametersDataViewModel
     * @return
     */
    public static boolean checkWashSendProcessParametersData(ProcessParametersDataViewModel processParametersDataViewModel) {
        if (!checkBaseSendProcessParametersData(processParametersDataViewModel)) return false;
        // 焊接功率
        if (!EngineerDataCheck.weldingPowerCheck(processParametersDataViewModel.getLaserPower(), processParametersDataViewModel.getStartPower()).isSuccess()) {
            return false;
        }
        if (!EngineerDataCheck.checkLaserPower(processParametersDataViewModel.getData(), processParametersDataViewModel.getAdvancedSetting())) {
            return false;
        }
        // 摆动频率
        if (!EngineerDataCheck.swingFrequencyCheck(processParametersDataViewModel.getSwingFrequency(), processParametersDataViewModel.getType()).isSuccess()) {
            return false;
        }
        // 焊接宽度
        if (!EngineerDataCheck.swingWidthCheck(
                processParametersDataViewModel.getSwingWidth(),
                processParametersDataViewModel.useMMUnit(),
                java.util.Objects.requireNonNullElse(
                        processParametersDataViewModel.getType(), ModelConstant.WELD_CLEAN)).isSuccess()) {
            return false;
        }
        // 吹气延时
        if (!EngineerDataCheck.blowDelayCheck(processParametersDataViewModel.getBlowDelay()).isSuccess()) {
            return false;
        }
        // 关气延时
        if (!EngineerDataCheck.closeAirDelayCheck(processParametersDataViewModel.getCloseAirDelay()).isSuccess()) {
            return false;
        }
        // 功率缓升
        if (!EngineerDataCheck.powerRampUpCheck(processParametersDataViewModel.getPowerRampUp()).isSuccess()) {
            return false;
        }
        // 功率缓降
        if (!EngineerDataCheck.powerRampDownCheck(processParametersDataViewModel.getPowerRampDown()).isSuccess()) {
            return false;
        }

        return true;
    }

    /**
     * 校验切割下发的参数
     *
     * @param processParametersDataViewModel
     * @return
     */
    public static boolean checkCutSendProcessParametersData(ProcessParametersDataViewModel processParametersDataViewModel) {
        if (!checkBaseSendProcessParametersData(processParametersDataViewModel)) return false;
        // 焊接功率
        if (!EngineerDataCheck.weldingPowerCheck(processParametersDataViewModel.getLaserPower(), processParametersDataViewModel.getStartPower()).isSuccess()) {
            return false;
        }
        if (!EngineerDataCheck.checkLaserPower(processParametersDataViewModel.getData(), processParametersDataViewModel.getAdvancedSetting())) {
            return false;
        }
        // 激光频率
//        if (!EngineerDataCheck.laserFrequencyCheck(processParametersDataViewModel.getLaserFrequency()).isSuccess()) {
//            return false;
//        }
        // 激光占空比
//        if (!EngineerDataCheck.laserDutyCycleCheck(processParametersDataViewModel.getLaserDutyCycle()).isSuccess()) {
//            return false;
//        }
        // 吹气延时
        if (!EngineerDataCheck.blowDelayCheck(processParametersDataViewModel.getBlowDelay()).isSuccess()) {
            return false;
        }
        // 关气延时
        if (!EngineerDataCheck.closeAirDelayCheck(processParametersDataViewModel.getCloseAirDelay()).isSuccess()) {
            return false;
        }
        // 功率缓升
        if (!EngineerDataCheck.powerRampUpCheck(processParametersDataViewModel.getPowerRampUp()).isSuccess()) {
            return false;
        }
        // 功率缓降
        if (!EngineerDataCheck.powerRampDownCheck(processParametersDataViewModel.getPowerRampDown()).isSuccess()) {
            return false;
        }
        // 穿孔频率
//        if (!EngineerDataCheck.perforationFrequencyCheck(processParametersDataViewModel.getPerforationFrequency()).isSuccess()) {
//            return false;
//        }
        // 穿孔时长
//        if (!EngineerDataCheck.perforationDurationCheck(processParametersDataViewModel.getPerforationDuration()).isSuccess()) {
//            return false;
//        }
        return true;
    }
}