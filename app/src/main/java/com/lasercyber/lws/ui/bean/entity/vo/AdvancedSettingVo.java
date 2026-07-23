package com.lasercyber.lws.ui.bean.entity.vo;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.common.utils.TemperatureUnitConvertUtil;

import cn.hutool.core.convert.Convert;
import lombok.Data;

@Data
public class AdvancedSettingVo {
    private Integer id;
    /**
     * 语言设置
     */
    private String languageSetting;
    /**
     * 单位设置
     */
    private Boolean unitSetting;
    /**
     * 零点校正
     */
    private String zeroPointCorrection;
    /**
     * 摆宽校正
     */
    private String properSwingWidth;
    /**
     * 激光起始功率
     */
    private String laserStartPower;
    /**
     * 激光终止功率
     */
    private String laserEndPower;
    /**
     * 吹气压力阈值
     *
     **/
    private String blowPressureThreshold;
    /**
     * 红光偏移
     */
    private String redLightOffset;
    /**
     * 摆速区间上限寄存器地址
     */
    private String swingSpeedUpperLimit;
    /**
     * 摆速区间下限寄存器地址
     */
    private String swingSpeedLowerLimit;
    /**
     * 手动送丝速度
     */
    private String manualWireFeedSpeed;
    /**
     * 手动抽丝速度
     */
    private String manualDrawStringSpeed;
    /**
     * 进气气压阈值
     */
    private String inletGasPressureThreshold;
    /**
     * 驱动器温度报警阈值
     */
    private String driverTemperatureAlarmThreshold;
    /**
     * 保护镜温度报警阈值
     */
    private String protectiveLensTemperatureAlarmThreshold;
    /**
     * 聚焦镜温度报警阈值
     */
    private String collimatingLensTemperatureAlarmThreshold;
    /**
     * 电机温度报警阈值
     */
    private String motorTemperatureAlarmThreshold;
    /**
     * 温度报警恢复差值
     */
    private String temperatureAlarmRecoveryInterval;


    private Integer zeroPointCorrectionInt;

    private Integer properSwingWidthInt;

    private Integer laserStartPowerInt;

    private Integer laserEndPowerInt;

    private Integer blowPressureThresholdInt;

    private Integer inletGasPressureThresholdInt;

    private Integer driverTemperatureAlarmThresholdInt;

    private Integer protectiveLensTemperatureAlarmThresholdInt;

    private Integer collimatingLensTemperatureAlarmThresholdInt;

    private Integer motorTemperatureAlarmThresholdInt;

    private Integer temperatureAlarmRecoveryIntervalInt;

    /*手动选择*/
    private Integer voiceCheck;

    /** Whether to show startup self-check on home entry. */
    private Boolean showBootSelfCheck;

    /** Live-weld lens contamination AI assistance during laser-on sessions. */
    private Boolean lensContaminationDetectionEnabled;

    /** Laser-on zero-point offset AI assistance during laser-on sessions. */
    private Boolean zeroPointOffsetDetectionEnabled;

    /** Keep laser on during coded alarms while already emitting. */
    private Boolean keepLaserOnWhileAlarmed;

    /** Allow laser enable while camera communication fault C002 is active. */
    private Boolean allowWorkAfterCameraAlarm;

    /** Allow laser enable while shielding gas alarm A001 is active. */
    private Boolean allowWorkAfterGasAlarm;

    /** Allow laser enable while unresolved L001 heavy lens contamination episode is active. */
    private Boolean allowWorkAfterLensContamination;

    /** Allow laser enable while wire feeder alarm W001/W002 is active. */
    private Boolean allowWorkAfterFeederAlarm;

    public String getZeroPointCorrection() {
        return StringUtils.isEmpty(zeroPointCorrection) ? "0" : Convert.toInt(zeroPointCorrection)+"";
    }

    public String getProperSwingWidth() {
        return StringUtils.isEmpty(properSwingWidth) ? "0" : Convert.toInt(properSwingWidth)+"" ;
    }

    public String getLaserStartPower() {
        return StringUtils.isEmpty(laserStartPower) ? "0" : Convert.toInt(laserStartPower)+"" ;
    }

    public String getLaserEndPower() {
        return StringUtils.isEmpty(laserEndPower) ? "0" : Convert.toInt(laserEndPower)+"" ;
    }

    public String getBlowPressureThreshold() {
        return StringUtils.isEmpty(blowPressureThreshold) ? "0" : Convert.toInt(blowPressureThreshold)+"" ;
    }

    public String getInletGasPressureThreshold() {
        return StringUtils.isEmpty(inletGasPressureThreshold) ? "0" : Convert.toInt(inletGasPressureThreshold)+"";
    }

    public String getDriverTemperatureAlarmThreshold() {
        return toCelsiusString(driverTemperatureAlarmThreshold, 70);
    }

    public String getDriverTemperatureAlarmThresholdDisplay() {
        return TemperatureUnitConvertUtil.toDisplay(toCelsiusInt(driverTemperatureAlarmThreshold, 70), unitSetting);
    }

    public String getProtectiveLensTemperatureAlarmThreshold() {
        return toCelsiusString(protectiveLensTemperatureAlarmThreshold, 70);
    }

    public String getProtectiveLensTemperatureAlarmThresholdDisplay() {
        return TemperatureUnitConvertUtil.toDisplay(toCelsiusInt(protectiveLensTemperatureAlarmThreshold, 70), unitSetting);
    }

    public String getCollimatingLensTemperatureAlarmThreshold() {
        return toCelsiusString(collimatingLensTemperatureAlarmThreshold, 65);
    }

    public String getCollimatingLensTemperatureAlarmThresholdDisplay() {
        return TemperatureUnitConvertUtil.toDisplay(toCelsiusInt(collimatingLensTemperatureAlarmThreshold, 65), unitSetting);
    }

    public String getMotorTemperatureAlarmThreshold() {
        return toCelsiusString(motorTemperatureAlarmThreshold, 70);
    }

    public String getMotorTemperatureAlarmThresholdDisplay() {
        return TemperatureUnitConvertUtil.toDisplay(toCelsiusInt(motorTemperatureAlarmThreshold, 70), unitSetting);
    }

    public String getTemperatureAlarmRecoveryInterval() {
        return toCelsiusString(temperatureAlarmRecoveryInterval, 5);
    }

    public String getTemperatureAlarmRecoveryIntervalDisplay() {
        return TemperatureUnitConvertUtil.toDisplay(toCelsiusInt(temperatureAlarmRecoveryInterval, 5), unitSetting);
    }

    private static String toCelsiusString(String stored, int defaultCelsius) {
        return StringUtils.isEmpty(stored) ? String.valueOf(defaultCelsius) : String.valueOf(Convert.toInt(stored));
    }

    private static int toCelsiusInt(String stored, int defaultCelsius) {
        return StringUtils.isEmpty(stored) ? defaultCelsius : Convert.toInt(stored);
    }


    /* 获取*/
    public Integer getZeroPointCorrectionInt() {
        int i = StringUtils.isEmpty(zeroPointCorrection) ? 0 : Convert.toInt(zeroPointCorrection);
        this.zeroPointCorrectionInt = i;
        return i;
    }

    public Integer getProperSwingWidthInt() {
        int i = StringUtils.isEmpty(properSwingWidth) ? 0 : Convert.toInt(properSwingWidth);
        this.properSwingWidthInt = i;
        return i;
    }

    public Integer getLaserStartPowerInt() {
        int i = StringUtils.isEmpty(laserStartPower) ? 0 : Convert.toInt(laserStartPower);
        this.laserStartPowerInt = i;
        return i;
    }

    public Integer getLaserEndPowerInt() {
        int i = StringUtils.isEmpty(laserEndPower) ? 0 : Convert.toInt(laserEndPower);
        this.laserEndPowerInt = i;
        return i;
    }

    public Integer getBlowPressureThresholdInt() {
        int i = StringUtils.isEmpty(blowPressureThreshold) ? 0 : Convert.toInt(blowPressureThreshold);
        this.blowPressureThresholdInt = i;
        return i;
    }

    public Integer getInletGasPressureThresholdInt() {
        int i = StringUtils.isEmpty(inletGasPressureThreshold) ? 0 : Convert.toInt(inletGasPressureThreshold);
        this.inletGasPressureThresholdInt = i;
        return i;
    }

    public Integer getDriverTemperatureAlarmThresholdInt() {
        int i = StringUtils.isEmpty(driverTemperatureAlarmThreshold) ? 70 : Convert.toInt(driverTemperatureAlarmThreshold);
        this.driverTemperatureAlarmThresholdInt = i;
        return i;
    }

    public Integer getProtectiveLensTemperatureAlarmThresholdInt() {
        int i = StringUtils.isEmpty(protectiveLensTemperatureAlarmThreshold) ? 70 : Convert.toInt(protectiveLensTemperatureAlarmThreshold);
        this.protectiveLensTemperatureAlarmThresholdInt = i;
        return i;
    }

    public Integer getCollimatingLensTemperatureAlarmThresholdInt() {
        int i = StringUtils.isEmpty(collimatingLensTemperatureAlarmThreshold) ? 65 : Convert.toInt(collimatingLensTemperatureAlarmThreshold);
        this.collimatingLensTemperatureAlarmThresholdInt = i;
        return i;
    }

    public Integer getMotorTemperatureAlarmThresholdInt() {
        int i = StringUtils.isEmpty(motorTemperatureAlarmThreshold) ? 70 : Convert.toInt(motorTemperatureAlarmThreshold);
        this.motorTemperatureAlarmThresholdInt = i;
        return i;
    }

    public Integer getTemperatureAlarmRecoveryIntervalInt() {
        int i = StringUtils.isEmpty(temperatureAlarmRecoveryInterval) ? 5 : Convert.toInt(temperatureAlarmRecoveryInterval);
        this.temperatureAlarmRecoveryIntervalInt = i;
        return i;
    }
}
