package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.bean.ui.DataEquals;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.utils.TemperatureUnitConvertUtil;

import java.io.Serializable;
import java.util.Locale;
import java.util.Objects;

import lombok.Data;

@Data
public class DeviceData implements Serializable, DataEquals<DeviceData>,Cloneable {
    // ========== 0060H-006FH：设备数据查询 ==========
    /**
     * 吹气气压（单位：kPa）
     */
    private Integer blowAirPressure;

    /**
     * 枪头电机温度（原始值，需解析）
     * 规则：有符号数，扩大10倍，保留1位小数；特殊值-999.0=未连接/错误；200.0=超温（会报警）
     */
    private Integer gunMotorTempRaw;

    /**
     * 枪头电机驱动板温度（原始值，需解析）
     * 规则：有符号数，扩大10倍，保留1位小数；特殊值-999.0=未连接/错误；200.0=超温（会报警）
     */
    private Integer gunDriverBoardTempRaw;

    /**
     * 保护镜温度（原始值，需解析）
     * 规则：有符号数，扩大10倍，保留1位小数；特殊值-999.0=未连接/错误；200.0=超温（会报警）
     */
    private Integer protectionBoardTempRaw;

    /**
     * 聚焦镜侧温（原始值，需解析）
     * 规则：有符号数，扩大10倍，保留1位小数；特殊值-999.0=未连接/错误；200.0=超温（会报警）
     */
    private Integer collimatorTempRaw;

    /**
     * 枪头24V电压（范围：0-36V）
     */
    private Integer gun24vVoltage;

    /**
     * 枪头24V电流（范围：0-2000mA）
     */
    private Integer gun24vCurrent;

    /**
     * 前向光PD电压
     */
    @Deprecated
    private Integer forwardLightPdVoltage;
    /**
     * 激光反馈功率
     * 单位（0.1w）
     */
    private Integer laserFeedbackPower;
    /**
     * 泵源板温度
     */
    private Integer pumpSourceBoardTemperature;
    /**
     * 泵源温度
     */
    private Integer pumpSourceTemperature;
    /**
     * 激光器电流
     */
    private Integer laserCurrent;
    /**
     * 激光器红光电流
     */
    private Integer laserRedCurrent;
    /**
     * 泵源电流（Modbus 0x0071）。
     *
     * @deprecated 寄存器读数不可靠；表盘与远程监测请使用 {@link #laserCurrent}（0x006F），
     *             表盘显示用 {@link #getPumpGaugeCurrentAmps()}。
     */
    @Deprecated
    private Integer pumpSourceCurrent;
    /**
     * 环境温度
     */
    private Integer environmentTemperature;

    /**
     * 最近 5 次设备数据轮询是否达到 C001 阈值（≥3 次不完整或失败）。
     */
    private Boolean modbusDataReadTruncated;

    public boolean isModbusDataReadTruncated() {
        return Boolean.TRUE.equals(modbusDataReadTruncated);
    }

    /** Transient display unit for UI formatting only; not persisted or cached. */
    private transient String displayUnit = UnitSystem.METRIC.getWireValue();

    public void setDisplayUnit(String unitWireValue) {
        this.displayUnit = unitWireValue != null ? unitWireValue : UnitSystem.METRIC.getWireValue();
    }

    public String getDisplayUnit() {
        return displayUnit;
    }

    /**
     * Machine Status 泵源表盘取数：Modbus 0x006F（{@link #laserCurrent} raw）。
     */
    public Integer getPumpGaugeCurrentRaw() {
        return laserCurrent;
    }

    /**
     * Machine Status 泵源表盘显示值（A）：{@link #laserCurrent} raw × 0.1。
     */
    public double getPumpGaugeCurrentAmps() {
        if (laserCurrent == null) {
            return 0d;
        }
        return laserCurrent * 0.1;
    }

    // ========================================
    // 数据解析工具方法（适配表格中的特殊规则）
    // ========================================

    /**
     * 解析枪头电机温度（转换为实际温度值）
     * @return 实际温度（单位：℃）；null=无效值
     */
    public String getGunMotorTempText() {
        return parseTemperature(gunMotorTempRaw);
    }

    /**
     * 枪头电机温度是否异常
     *
     * @return
     */
    public boolean isGunMotorTempError() {
        return gunMotorTempRaw != null && gunMotorTempRaw <= -999;
    }

    public boolean hasGunMotorTempValue() {
        return hasTemperatureValue(gunMotorTempRaw);
    }
    /**
     * 解析枪头电机驱动板温度（转换为实际温度值）
     * @return 实际温度（单位：℃）；null=无效值
     */
    public String getGunDriverBoardTempText() {
        return parseTemperature(gunDriverBoardTempRaw);
    }

    /**
     * 枪头电机驱动板温度异常
     *
     * @return
     */
    public boolean isGunDriverBoardTempError() {
        return gunDriverBoardTempRaw != null && gunDriverBoardTempRaw <= -999;
    }

    public boolean hasGunDriverBoardTempValue() {
        return hasTemperatureValue(gunDriverBoardTempRaw);
    }
    /**
     * 解析保护镜温度（转换为实际温度值）
     * @return 实际温度（单位：℃）；null=无效值
     */
    public String getProtectionBoardTempText() {
        return parseTemperature(protectionBoardTempRaw);
    }

    /**
     * 解析聚焦镜侧温（转换为实际温度值）
     * @return 实际温度（单位：℃）；null=无效值
     */
    public String getCollimatorTempText() {
        return parseTemperature(collimatorTempRaw);
    }

    /**
     * 保护镜温度传感器未连接/错误（与 {@link #getGunMotorTempText} 等相同特殊值规则）
     */
    public boolean isProtectionBoardTempError() {
        return protectionBoardTempRaw != null && protectionBoardTempRaw <= -999;
    }

    public boolean hasProtectionBoardTempValue() {
        return hasTemperatureValue(protectionBoardTempRaw);
    }

    /**
     * 聚焦镜温度传感器未连接/错误
     */
    public boolean isCollimatorTempError() {
        return collimatorTempRaw != null && collimatorTempRaw <= -999;
    }

    public boolean hasCollimatorTempValue() {
        return hasTemperatureValue(collimatorTempRaw);
    }

    private static boolean hasTemperatureValue(Integer rawValue) {
        return rawValue != null && rawValue > -999;
    }

    /**
     * 通用温度解析方法（适配表格规则）
     * @param rawValue 寄存器原始值
     * @return 实际温度（单位：℃）；null=无效值
     */
    private String parseTemperature(Integer rawValue) {
        if (rawValue == null || rawValue <= -999) {
            return TemperatureUnitConvertUtil.invalidTemperaturePlaceholder(displayUnit);
        }
        return TemperatureUnitConvertUtil.formatSensorCelsius(rawValue / 10.0, displayUnit);
    }

    /**
     * 获取吹气气压的实际值（单位：kPa）
     * @return 实际气压值；null=无效值
     */
    public String getBlowAirPressureText() {
        return blowAirPressure==null ? "- kPa" : blowAirPressure +" kPa"; // 无特殊规则，直接返回原始值
    }

    /**
     * 获取枪头24V电压的实际值（单位：V）
     * @return 实际电压值；null=无效值
     */
    public String getGun24vVoltageText() {
        return gun24vVoltage==null ? "- V" : gun24vVoltage+" V";
    }

    /**
     * 获取枪头24V电流的实际值（单位：mA）
     * @return 实际电流值；null=无效值
     */
    public String getGun24vCurrentText() {
        return gun24vCurrent==null ? "- mA" : gun24vCurrent+" mA";
    }

    /**
     * 向前光PD电压
     * @return
     */
    public String getForwardLightPdVoltageText(){
        return forwardLightPdVoltage==null ? "- V" : (forwardLightPdVoltage*0.1)+" V";
    }

    /**
     * 激光反馈功率
     * @return
     */
    public String getLaserFeedbackPowerText(){
        if (this.laserFeedbackPower==null){
            return "- W";
        }
        return this.laserFeedbackPower*10+" W";
    }
    /**
     * 获取泵源板温度的实际值（单位：℃）
     * @return 泵源板温度；null=无效值
     */
    public String getPumpSourceBoardTemperatureText(){
        if (pumpSourceBoardTemperature == null) {
            return TemperatureUnitConvertUtil.invalidTemperaturePlaceholder(displayUnit);
        }
        return TemperatureUnitConvertUtil.formatIntegerCelsius(pumpSourceBoardTemperature, displayUnit);
    }
    /**
     * 获取泵源温度的实际值（单位：℃）
     */
    public String getPumpSourceTemperatureText(){
        if (pumpSourceTemperature == null) {
            return TemperatureUnitConvertUtil.invalidTemperaturePlaceholder(displayUnit);
        }
        return TemperatureUnitConvertUtil.formatIntegerCelsius(pumpSourceTemperature, displayUnit);
    }
    /**
     * 获取激光器电流的实际值（单位：mA）
     */
    public String getLaserCurrentText(){
        return laserCurrent==null ? "- mA" : laserCurrent+" mA";
    }
    /**
     *  激光器红光电流
     */
    public String getLaserRedCurrentText(){
        return laserRedCurrent==null ? "- mA" : laserRedCurrent+" mA";
    }
    /**
     * 泵源电流展示文本。
     *
     * @deprecated 请使用 {@link #getLaserCurrentText()}。
     */
    @Deprecated
    public String getPumpSourceCurrentText(){
        return pumpSourceCurrent==null ? "- mA" : pumpSourceCurrent+" mA";
    }
    /**
     *  环境温度
     */
    public String getEnvironmentTemperatureText(){
        if (environmentTemperature == null) {
            return TemperatureUnitConvertUtil.invalidTemperaturePlaceholder(displayUnit);
        }
        return TemperatureUnitConvertUtil.formatIntegerCelsius(environmentTemperature, displayUnit);
    }
    /**
     * 对比数据是否发生变更
     * @param newData 新数据
     * @return
     */
    @Override
    public boolean dataChange(DeviceData newData) {
        // 1. 新数据为null → 视为无变化（若业务需将“数据缺失”视为变化，可改为return true）
        if (newData == null) {
            return false;
        }
        // 2. 对比所有业务字段（原始值，避免解析后的文本对比导致的无效差异）
        // 吹气气压
        if (!Objects.equals(this.blowAirPressure, newData.blowAirPressure)) return true;
        // 温度类原始值（直接对比寄存器原始值，而非解析后的文本）
        if (!Objects.equals(this.gunMotorTempRaw, newData.gunMotorTempRaw)) return true;
        if (!Objects.equals(this.gunDriverBoardTempRaw, newData.gunDriverBoardTempRaw)) return true;
        if (!Objects.equals(this.protectionBoardTempRaw, newData.protectionBoardTempRaw)) return true;
        if (!Objects.equals(this.collimatorTempRaw, newData.collimatorTempRaw)) return true;
        // 枪头24V电压/电流
        if (!Objects.equals(this.gun24vVoltage, newData.gun24vVoltage)) return true;
        if (!Objects.equals(this.gun24vCurrent, newData.gun24vCurrent)) return true;
        // 前向光PD电压
        if (!Objects.equals(this.forwardLightPdVoltage, newData.forwardLightPdVoltage)) return true;
        // 激光反馈功率
        if(!Objects.equals(this.laserFeedbackPower,newData.laserFeedbackPower)) return true;
        // 泵源板温度/泵源温度
        if (!Objects.equals(this.pumpSourceBoardTemperature, newData.pumpSourceBoardTemperature)) return true;
        if (!Objects.equals(this.pumpSourceTemperature, newData.pumpSourceTemperature)) return true;
        // 激光器电流/激光器红光电流/泵源电流
        if (!Objects.equals(this.laserCurrent, newData.laserCurrent)) return true;
        if (!Objects.equals(this.laserRedCurrent, newData.laserRedCurrent)) return true;
        if (!Objects.equals(this.pumpSourceCurrent, newData.pumpSourceCurrent)) return true;
        if (!Objects.equals(this.environmentTemperature, newData.environmentTemperature)) return true;
        if (!Objects.equals(this.modbusDataReadTruncated, newData.modbusDataReadTruncated)) return true;
        // 3. 所有字段均无变化 → 返回false
        return false;
    }

    @Override
    public DeviceData clone() {
        try {
            DeviceData copy = (DeviceData) super.clone();
            copy.displayUnit = this.displayUnit;
            return copy;
        } catch (CloneNotSupportedException e) {
            throw new AssertionError();
        }
    }
}
