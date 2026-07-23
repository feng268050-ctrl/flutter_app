package com.lasercyber.lws.ui.bean.entity;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.ui.DataEquals;
import com.lasercyber.lws.ui.common.constant.DeviceUpgradeConstant;

import java.io.Serializable;
import java.util.Objects;

import lombok.Data;

/**
 * 设备状态，定时从设备上拉取
 */
@Data
public class DeviceStatus implements Serializable, DataEquals<DeviceStatus>,Cloneable{
    /**
     * 摄像头通讯状态（HTTP 探测结果）。用于远程快照/外部监视器消费。
     *
     * <p>取值约定：1 = healthy（可通讯），0 = fault（不可通讯）。</p>
     */
    private Integer cameraStatus;
    // ========== 0000H-0008H：状态字（OTA升级相关） ==========
    /**
     * 设备类型（0:未知；1:LSW01控制板；其他:预留）
     */
    private Integer deviceType;
    /**
     * 设备硬件版本
     */
    private Integer hardwareVersion;
    /**
     * 设备软件版本
     */
    private Integer softwareVersion;
    /**
     * OTA升级命令（0x0000:无效；0x1234:请求固件信息；0x65A4:请求固件数据；0x1212:升级成功；0x0020:升级失败）
     */
    private Integer otaUpgradeCmd;
    /**
     * 请求固件版本硬件
     */
    private Integer reqHardFirmwareVersion;
    /**
     * 请求软件版本
     */
    private Integer reqSoftwareVersion;
    /**
     * 请求固件偏移地址（低字节）
     */
    private Integer reqFirmwareOffsetLow;
    /**
     * 请求固件偏移地址（高字节）
     */
    private Integer reqFirmwareOffsetHigh;
    /**
     * 请求固件数据长度
     */
    private Integer reqFirmwareDataLength;

    // ========== 0009H-000CH：枪头告警状态字 ==========
    /**
     * 枪头告警状态段1（Bit0:枪头通信；Bit1~Bit15:预留）
     */
    private Integer gunAlarmSeg1;
    /**
     * 枪头告警状态段3（Bit0:传感器通道差异；Bit1:静态电流异常；Bit2:电机连接线开路；Bit3:传感器异常；Bit4:FLASH出错；Bit5:FLASH未加密；Bit6~Bit7:预留）
     */
    private Integer gunAlarmSeg3;
    /**
     * 枪头告警状态段2（Bit0:电机过温报警；Bit1:驱动器温度报警；Bit2:保护镜温度；Bit3:直道温度；Bit4:24V欠压；Bit5:驱动过流；Bit6:电机轨迹异常；Bit7:电机堵转；Bit8~Bit15:预留）
     */
    private Integer gunAlarmSeg2;
    /**
     * 枪头告警状态段4（Bit0:MMI晶振异常；Bit1:硬件总线错误；Bit2:内存管理异常；Bit3:内存访问出错；Bit4:非法指令；Bit5:看门狗重启；Bit6~Bit7:预留）
     */
    private Integer gunAlarmSeg4;

    // ========== 000DH-0011H：激光器告警状态字 ==========
    /**
     * 激光器告警状态段1（Bit0:激光器通信；Bit1:泵源板温度；Bit2:泵源温度；Bit3:电流；Bit4:红光电流；Bit5:泵源电压；Bit6:前向光PD电压；Bit7~Bit14:预留）
     */
    private Integer laserAlarmSeg1;
    /**
     * 激光器告警状态段2（Bit0:1号驱动通讯；Bit1:2号驱动通讯；Bit2:3号驱动通讯；Bit3:4号驱动通讯；Bit4:AD反馈通讯；Bit5:泵浦模块超温；Bit6:驱动模块超温；Bit7:水温超限；Bit8:光纤温度超上限；Bit9:激光反射能量超上限；Bit10:激光输出能量超下限；Bit11:二极管短路故障；Bit12:光纤断开；Bit13:内部湿度超上限；Bit14:冷水互锁；Bit15:急停）
     */
    private Integer laserAlarmSeg2;
    /**
     * 激光器告警状态段3（Bit0:定位光故障；Bit1:窄脉冲保护；Bit2~Bit15:预留）
     */
    private Integer laserAlarmSeg3;
    /**
     * 激光器告警状态段4（预留）
     */
    private Integer laserAlarmSeg4;

    // ========== 0012H-0013H：送丝机告警状态字 ==========
    /**
     * 送丝机告警状态段1（Bit0:送丝机通信；Bit1:电流告警；Bit2~Bit15:预留）
     */
    private Integer wireFeederAlarmSeg1;
    /**
     * 送丝机告警状态段2（预留）
     */
    private Integer wireFeederAlarmSeg2;

    // ========== 0014H-0016H：控制卡+机台状态字 ==========
    /**
     * 控制卡告警状态段1（Bit0:吹气气压；Bit1:进气气压；Bit2:气压传感器通信；Bit3:外部Flash）
     */
    private Integer controlCardAlarmSeg1;
    /**
     * 控制卡告警状态段2（预留）
     */
    private Integer controlCardAlarmSeg2;
    /**
     * 机台状态段1（Bit0:激光状态；Bit1:枪头开关；Bit2:送丝状态；Bit3:红光状态；Bit4:气阀状态；Bit5:安全地锁状态；Bit6:钥匙开关；Bit7:急停开关；Bit8:安全门；Bit9~Bit15:预留）
     */
    private Integer machineStatusSeg1;
    /**
     * 机台状态段2（预留）
     */
    private Integer machineStatusSeg2;

    /**
     * 最近 5 次设备状态轮询是否达到 C001 阈值（≥3 次不完整或失败）。
     */
    private Boolean modbusStatusReadTruncated;

    // ========== 0017H-002FH：预留 ==========
    /**
     * 预留字段1（0017H）
     */
    @Deprecated
    private Integer reserveSeg1;
    /**
     * 预留字段2（0018H）
     */
    @Deprecated
    private Integer reserveSeg2;
    /**
     * 预留字段3（0019H）
     */
    @Deprecated
    private Integer reserveSeg3;
    /**
     * 预留字段4（001AH）
     */
    @Deprecated
    private Integer reserveSeg4;
    /**
     * 预留字段5（001BH）
     */
    @Deprecated
    private Integer reserveSeg5;
    /**
     * 预留字段6（001CH）
     */
    @Deprecated
    private Integer reserveSeg6;
    /**
     * 预留字段7（001DH）
     */
    @Deprecated
    private Integer reserveSeg7;
    /**
     * 预留字段8（001EH）
     */
    @Deprecated
    private Integer reserveSeg8;
    /**
     * 预留字段9（001FH）
     */
    @Deprecated
    private Integer reserveSeg9;
    /**
     * 预留字段10（0020H）
     */
    @Deprecated
    private Integer reserveSeg10;
    /**
     * 预留字段11（0021H）
     */
    @Deprecated
    private Integer reserveSeg11;
    /**
     * 预留字段12（0022H）
     */
    @Deprecated
    private Integer reserveSeg12;
    /**
     * 预留字段13（0023H）
     */
    @Deprecated
    private Integer reserveSeg13;
    /**
     * 预留字段14（0024H）
     */
    @Deprecated
    private Integer reserveSeg14;
    /**
     * 预留字段15（0025H）
     */
    @Deprecated
    private Integer reserveSeg15;
    /**
     * 预留字段16（0026H）
     */
    @Deprecated
    private Integer reserveSeg16;
    /**
     * 预留字段17（0027H）
     */
    @Deprecated
    private Integer reserveSeg17;
    /**
     * 预留字段18（0028H）
     */
    @Deprecated
    private Integer reserveSeg18;
    /**
     * 预留字段19（0029H）
     */
    @Deprecated
    private Integer reserveSeg19;
    /**
     * 预留字段20（002AH）
     */
    @Deprecated
    private Integer reserveSeg20;
    /**
     * 预留字段21（002BH）
     */
    @Deprecated
    private Integer reserveSeg21;
    /**
     * 预留字段22（002CH）
     */
    @Deprecated
    private Integer reserveSeg22;
    /**
     * 预留字段23（002DH）
     */
    @Deprecated
    private Integer reserveSeg23;
    /**
     * 预留字段24（002EH）
     */
    @Deprecated
    private Integer reserveSeg24;
    /**
     * 预留字段25（002FH）
     */
    @Deprecated
    private Integer reserveSeg25;

    // ========================================
    // 通用Bit位解析工具方法（核心）
    // ========================================

    /**
     * 通用方法：判断某个整数字段的指定Bit位是否为1（1=有效/告警/开启，0=无效/正常/关闭）
     *
     * @param fieldValue 字段值（如gunAlarmSeg1）
     * @param bitIndex   Bit位索引（从0开始，0=最低位，15=最高位）
     * @return true=Bit位为1，false=Bit位为0（字段为null时返回false）
     */
    public boolean isBitSet(Integer fieldValue, int bitIndex) {
        if (fieldValue == null) {
            return false;
        }
        // 校验Bit位索引合法性（16位寄存器，索引0-15）
        if (bitIndex < 0 || bitIndex > 15) {
            throw new IllegalArgumentException("Bit位索引必须在0-15之间");
        }
        return (1  & (fieldValue >> bitIndex)) != 0;
    }

    /**
     * Whether any scanned hardware alarm segment is non-zero (gun, laser, wire feeder, control card).
     */
    public boolean hasAnyHardwareAlarm() {
        return isAlarmSegmentActive(gunAlarmSeg1)
                || isAlarmSegmentActive(gunAlarmSeg2)
                || isAlarmSegmentActive(gunAlarmSeg3)
                || isAlarmSegmentActive(gunAlarmSeg4)
                || isAlarmSegmentActive(laserAlarmSeg1)
                || isAlarmSegmentActive(laserAlarmSeg2)
                || isAlarmSegmentActive(laserAlarmSeg3)
                || isAlarmSegmentActive(laserAlarmSeg4)
                || isAlarmSegmentActive(wireFeederAlarmSeg1)
                || isAlarmSegmentActive(wireFeederAlarmSeg2)
                || isAlarmSegmentActive(controlCardAlarmSeg1)
                || isAlarmSegmentActive(controlCardAlarmSeg2);
    }

    private static boolean isAlarmSegmentActive(Integer segment) {
        return segment != null && segment != 0;
    }

    // ========================================
    // 枪头告警状态专项解析方法
    // ========================================

    /**
     * 枪头通信告警（gunAlarmSeg1 Bit0）
     */
    public boolean isGunCommunicationAlarm() {
        return isBitSet(this.gunAlarmSeg1, 0);
    }

    /**
     * 传感器通道差异告警（gunAlarmSeg3 Bit0）
     */
    public boolean isSensorChannelDiffAlarm() {
        return isBitSet(this.gunAlarmSeg3, 0);
    }

    /**
     * 静态电流异常告警（gunAlarmSeg3 Bit1）
     */
    public boolean isStaticCurrentAbnormalAlarm() {
        return isBitSet(this.gunAlarmSeg3, 1);
    }

    /**
     * 电机连接线开路告警（gunAlarmSeg3 Bit2）
     */
    public boolean isMotorWireOpenAlarm() {
        return isBitSet(this.gunAlarmSeg3, 2);
    }

    /**
     * 传感器异常告警（gunAlarmSeg3 Bit3）
     */
    public boolean isSensorAbnormalAlarm() {
        return isBitSet(this.gunAlarmSeg3, 3);
    }

    /**
     * FLASH出错告警（gunAlarmSeg3 Bit4）
     */
    public boolean isFlashErrorAlarm() {
        return isBitSet(this.gunAlarmSeg3, 4);
    }

    /**
     * FLASH未加密告警（gunAlarmSeg3 Bit5）
     */
    public boolean isFlashUnencryptedAlarm() {
        return isBitSet(this.gunAlarmSeg3, 5);
    }

    /**
     * 电机过温告警（gunAlarmSeg2 Bit0）
     */
    public boolean isGunMotorOverTemperatureAlarm() {
        return isBitSet(this.gunAlarmSeg2, 0);
    }

    /**
     * 驱动温度告警（gunAlarmSeg2 Bit1）
     */
    public boolean isDriverTemperatureAlarm() {
        return isBitSet(this.gunAlarmSeg2, 1);
    }

    /**
     * 保护镜温度告警（gunAlarmSeg2 Bit2）
     */
    public boolean isProtectionBoardTemperatureAlarm() {
        return isBitSet(this.gunAlarmSeg2, 2);
    }

    /**
     * 聚焦镜温度报警（gunAlarmSeg2 Bit3）
     */
    public boolean isStraightTrackTemperatureAlarm() {
        return isBitSet(this.gunAlarmSeg2, 3);
    }

    /**
     * 24V欠压告警（gunAlarmSeg2 Bit4）
     */
    public boolean is24VUnderVoltageAlarm() {
        return isBitSet(this.gunAlarmSeg2, 4);
    }

    /**
     * 驱动过流告警（gunAlarmSeg2 Bit5）
     */
    public boolean isDriverOverCurrentAlarm() {
        return isBitSet(this.gunAlarmSeg2, 5);
    }

    /**
     * 电机轨迹异常告警（gunAlarmSeg2 Bit6）
     */
    public boolean isMotorTrackAbnormalAlarm() {
        return isBitSet(this.gunAlarmSeg2, 6);
    }

    /**
     * 电机堵转告警（gunAlarmSeg2 Bit7）
     */
    public boolean isMotorStallAlarm() {
        return isBitSet(this.gunAlarmSeg2, 7);
    }

    /**
     * MMI晶振异常告警（gunAlarmSeg4 Bit0）
     */
    public boolean isMmiOscillatorAbnormalAlarm() {
        return isBitSet(this.gunAlarmSeg4, 0);
    }

    /**
     * 硬件总线错误告警（gunAlarmSeg4 Bit1）
     */
    public boolean isHardwareBusErrorAlarm() {
        return isBitSet(this.gunAlarmSeg4, 1);
    }

    /**
     * 内存管理异常告警（gunAlarmSeg4 Bit2）
     */
    public boolean isMemoryManagementAbnormalAlarm() {
        return isBitSet(this.gunAlarmSeg4, 2);
    }

    /**
     * 内存访问出错告警（gunAlarmSeg4 Bit3）
     */
    public boolean isMemoryAccessErrorAlarm() {
        return isBitSet(this.gunAlarmSeg4, 3);
    }

    /**
     * 非法指令告警（gunAlarmSeg4 Bit4）
     */
    public boolean isIllegalInstructionAlarm() {
        return isBitSet(this.gunAlarmSeg4, 4);
    }

    /**
     * 看门狗重启告警（gunAlarmSeg4 Bit5）
     */
    public boolean isWatchdogResetAlarm() {
        return isBitSet(this.gunAlarmSeg4, 5);
    }

    // ========================================
    // 激光器告警状态专项解析方法
    // ========================================

    /**
     * 激光器通信告警（laserAlarmSeg1 Bit0）
     */
    public boolean isLaserCommunicationAlarm() {
        return isBitSet(this.laserAlarmSeg1, 0);
    }

    /**
     * 泵源板温度告警（laserAlarmSeg1 Bit1）
     */
    public boolean isPumpBoardTemperatureAlarm() {
        return isBitSet(this.laserAlarmSeg1, 1);
    }

    /**
     * 泵源温度告警（laserAlarmSeg1 Bit2）
     */
    public boolean isPumpHumidityAlarm() {
        return isBitSet(this.laserAlarmSeg1, 2);
    }

    /**
     * 电流告警（laserAlarmSeg1 Bit3）
     */
    public boolean isLaserCurrentAlarm() {
        return isBitSet(this.laserAlarmSeg1, 3);
    }

    /**
     * 红光电流告警（laserAlarmSeg1 Bit4）
     */
    public boolean isRedLightCurrentAlarm() {
        return isBitSet(this.laserAlarmSeg1, 4);
    }

    /**
     * 泵源电压告警（laserAlarmSeg1 Bit5）
     */
    public boolean isPumpVoltageAlarm() {
        return isBitSet(this.laserAlarmSeg1, 5);
    }

    /**
     * 前向光PD电压告警（laserAlarmSeg1 Bit6）
     */
    @Deprecated
    public boolean isForwardLightPdVoltageAlarm() {
        return isBitSet(this.laserAlarmSeg1, 6);
    }

    /**
     * 内部温度告警
     * @return
     */
    @Deprecated
    public boolean isInternalTemperatureWarning(){
        return isBitSet(this.laserAlarmSeg1, 7);
    }
    /**
     * 1号驱动通讯告警（laserAlarmSeg2 Bit0）
     */
    public boolean isDriver1CommunicationAlarm() {
        return isBitSet(this.laserAlarmSeg2, 0);
    }

    /**
     * 2号驱动通讯告警（laserAlarmSeg2 Bit1）
     */
    public boolean isDriver2CommunicationAlarm() {
        return isBitSet(this.laserAlarmSeg2, 1);
    }

    /**
     * 3号驱动通讯告警（laserAlarmSeg2 Bit2）
     */
    public boolean isDriver3CommunicationAlarm() {
        return isBitSet(this.laserAlarmSeg2, 2);
    }

    /**
     * 4号驱动通讯告警（laserAlarmSeg2 Bit3）
     */
    public boolean isDriver4CommunicationAlarm() {
        return isBitSet(this.laserAlarmSeg2, 3);
    }

    /**
     * AD反馈通讯告警（laserAlarmSeg2 Bit4）
     */
    public boolean isAdFeedbackCommunicationAlarm() {
        return isBitSet(this.laserAlarmSeg2, 4);
    }

    /**
     * 泵浦模块超温告警（laserAlarmSeg2 Bit5）
     */
    public boolean isPumpModuleOverTemperatureAlarm() {
        return isBitSet(this.laserAlarmSeg2, 5);
    }

    /**
     * 驱动模块超温告警（laserAlarmSeg2 Bit6）
     */
    public boolean isDriverModuleOverTemperatureAlarm() {
        return isBitSet(this.laserAlarmSeg2, 6);
    }

    /**
     * 水温超限告警（laserAlarmSeg2 Bit7）
     */
    public boolean isWaterTemperatureOverLimitAlarm() {
        return isBitSet(this.laserAlarmSeg2, 7);
    }

    /**
     * 光纤温度超上限告警（laserAlarmSeg2 Bit8）
     */
    public boolean isFiberTemperatureOverLimitAlarm() {
        return isBitSet(this.laserAlarmSeg2, 8);
    }

    /**
     * 激光反射能量超上限告警（laserAlarmSeg2 Bit9）
     */
    public boolean isLaserReflectionEnergyOverLimitAlarm() {
        return isBitSet(this.laserAlarmSeg2, 9);
    }

    /**
     * 激光输出能量超下限告警（laserAlarmSeg2 Bit10）
     */
    public boolean isLaserOutputEnergyUnderLimitAlarm() {
        return isBitSet(this.laserAlarmSeg2, 10);
    }

    /**
     * 二极管短路故障告警（laserAlarmSeg2 Bit11）
     */
    public boolean isDiodeShortCircuitAlarm() {
        return isBitSet(this.laserAlarmSeg2, 11);
    }

    /**
     * 光纤断开告警（laserAlarmSeg2 Bit12）
     */
    public boolean isFiberDisconnectedAlarm() {
        return isBitSet(this.laserAlarmSeg2, 12);
    }

    /**
     * 内部湿度超上限告警（laserAlarmSeg2 Bit13）
     */
    public boolean isInternalHumidityOverLimitAlarm() {
        return isBitSet(this.laserAlarmSeg2, 13);
    }

    /**
     * 冷水互锁告警（laserAlarmSeg2 Bit14）
     */
    public boolean isColdWaterInterlockAlarm() {
        return isBitSet(this.laserAlarmSeg2, 14);
    }

    /**
     * 激光器急停告警（laserAlarmSeg2 Bit15）
     */
    public boolean isLaserEmergencyStopAlarm() {
        return isBitSet(this.laserAlarmSeg2, 15);
    }

    /**
     * 定位光故障告警（laserAlarmSeg3 Bit0）
     */
    public boolean isPositioningLightFaultAlarm() {
        return isBitSet(this.laserAlarmSeg3, 0);
    }

    /**
     * 窄脉冲保护告警（laserAlarmSeg3 Bit1）
     */
    public boolean isNarrowPulseProtectionAlarm() {
        return isBitSet(this.laserAlarmSeg3, 1);
    }
    /**
     * 驱动板过压 (laserAlarmSeg3 Bit2)
     */
    public boolean  isLaserDriveBoardOvervoltage(){
        return isBitSet(this.laserAlarmSeg3, 2);
    }
    /**
     * 环境温度告警(laserAlarmSeg3 Bit3)
     */
    public boolean  isLaserEnvironmentalTemperatureAlarm(){
        return isBitSet(this.laserAlarmSeg3, 2);
    }
    // ========================================
    // 送丝机告警状态专项解析方法
    // ========================================

    /**
     * 送丝机通信告警（wireFeederAlarmSeg1 Bit0）
     */
    public boolean isWireFeederCommunicationAlarm() {
        return isBitSet(this.wireFeederAlarmSeg1, 0);
    }

    /**
     * 送丝机电流告警（wireFeederAlarmSeg1 Bit1）
     */
    public boolean isWireFeederCurrentAlarm() {
        return isBitSet(this.wireFeederAlarmSeg1, 1);
    }
    // ========================================
    // 控制卡告警状态专项解析方法
    // ========================================

    /**
     * 主控板与平板 Modbus 状态读数不完整（截断响应）。
     */
    public boolean isModbusStatusReadTruncated() {
        return Boolean.TRUE.equals(this.modbusStatusReadTruncated);
    }

    /**
     * 控制卡气压告警
     * @return
     */
    public boolean isPressureAlarm(){
        return isBitSet(this.controlCardAlarmSeg1, 0);
    }
    /**
     * 控制卡进气气压告警
     */
    public boolean isControllerCardAirIntakePressureWarning(){
        return isBitSet(this.controlCardAlarmSeg1, 1);
    }
    /**
     * 控制卡气压传感器通信故障
     */
    public boolean isControllerCardCommunicationFailurePressureSensor(){
        return isBitSet(this.controlCardAlarmSeg1, 2);
    }
    /**
     * 控制卡外部flash故障
     */
    public boolean isControllerCardExternalFlashMalfunction(){
        return isBitSet(this.controlCardAlarmSeg1, 3);
    }
    // ========================================
    // 机台状态专项解析方法（非告警，是运行状态）
    // ========================================

    /**
     * 激光状态（开启/关闭）（machineStatusSeg1 Bit0）
     *
     * @return true=激光开启，false=激光关闭
     */
    public boolean isLaserOn() {
        return isBitSet(this.machineStatusSeg1, 0);
    }

    /**
     * 枪的状态（开启/关闭）（machineStatusSeg1 Bit1）
     *
     * @return true=枪开启，false=枪关闭
     */
    public boolean gunStatus() {
        return isBitSet(this.machineStatusSeg1, 1);
    }

    /**
     * 送丝状态（开启/关闭）（machineStatusSeg1 Bit2）
     *
     * @return true=送丝开启，false=送丝关闭
     */
    public boolean isWireFeedingOn() {
        return isBitSet(this.machineStatusSeg1, 2);
    }

    /**
     * 红光状态（开启/关闭）（machineStatusSeg1 Bit3）
     *
     * @return true=红光开启，false=红光关闭
     */
    public boolean isRedLightOn() {
        return isBitSet(this.machineStatusSeg1, 3);
    }

    /**
     * 气阀状态（开启/关闭）（machineStatusSeg1 Bit4）
     *
     * @return true=气阀开启，false=气阀关闭
     */
    public boolean isAirValveOn() {
        return isBitSet(this.machineStatusSeg1, 4);
    }

    /**
     * 安全地锁状态（锁定/未锁定）（machineStatusSeg1 Bit5）
     *
     * @return true=安全地锁锁定，false=未锁定
     */
    public boolean isSafetyGroundLockLocked() {
        return isBitSet(this.machineStatusSeg1, 5);
    }

    /**
     * 钥匙开关状态（开启/关闭）（machineStatusSeg1 Bit6）
     *
     * @return true=钥匙开关开启，false=关闭
     */
    public boolean isKeySwitchOn() {
        return isBitSet(this.machineStatusSeg1, 6);
    }

    /**
     * 急停开关状态（触发/未触发）（machineStatusSeg1 Bit7）
     *
     * @return true=急停触发，false=未触发
     */
    public boolean isEmergencyStopTriggered() {
        return isBitSet(this.machineStatusSeg1, 7);
    }

    /**
     * 安全门状态（关闭/开启）（machineStatusSeg1 Bit8）
     *
     * @return true=安全门关闭（正常状态），false=安全门开启
     */
    public boolean isSafetyDoorClosed() {
        return isBitSet(this.machineStatusSeg1, 8);
    }

    /**
     * 请求固件信息
     * @return
     */
    public boolean requestFirmwareInfo(){
        return Objects.equals(this.otaUpgradeCmd, DeviceUpgradeConstant.REQUEST_FIRMWARE_INFO);
    }

    /**
     * 请求固件数据
     * @return
     */
    public boolean requestFirmwareData(){
        return Objects.equals(this.otaUpgradeCmd, DeviceUpgradeConstant.REQUEST_FIRMWARE_DATA);
    }
    /**
     * 升级成功
     */
    public boolean upgradeSuccess(){
        return Objects.equals(this.otaUpgradeCmd, DeviceUpgradeConstant.UPGRADE_SUCCESS);
    }
    /**
     * 升级失败
     */
    public boolean upgradeFail(){
        return Objects.equals(this.otaUpgradeCmd, DeviceUpgradeConstant.UPGRADE_FAIL);
    }

    /**
     * 获取固件偏移地址
     * @return
     */
    public int getReqFirmwareOffset() {
        return (this.getReqFirmwareOffsetHigh() << 8) | this.getReqFirmwareOffsetLow();
    }
    /**
     * 枪头状态（开启/关闭）（machineStatusSeg1 Bit9）
     * @return true=枪头开启，false=枪头关闭
     */
    public boolean isGunSwitchOn() {
        return isBitSet(this.machineStatusSeg1, 9);
    }

    /**
     * 是否连接了CNC
     *
     * @return
     */
    public boolean isConnectCNC() {
        return isBitSet(this.machineStatusSeg1, 10);
    }
    @Override
    public boolean dataChange(DeviceStatus newData) {
        if (newData == null) {
            return true;
        }
        if (!Objects.equals(cameraStatus, newData.cameraStatus)) {
            return true;
        }
        // 比较OTA升级相关字段
        if (!Objects.equals(deviceType, newData.deviceType)) {
            return true;
        }
        if (!Objects.equals(hardwareVersion, newData.hardwareVersion)) {
            return true;
        }
        if (!Objects.equals(softwareVersion, newData.softwareVersion)) {
            return true;
        }
        if (!Objects.equals(otaUpgradeCmd, newData.otaUpgradeCmd)) {
            return true;
        }
        if (!Objects.equals(reqHardFirmwareVersion, newData.reqHardFirmwareVersion)) {
            return true;
        }
        if (!Objects.equals(reqSoftwareVersion, newData.reqSoftwareVersion)) {
            return true;
        }
        if (!Objects.equals(reqFirmwareOffsetLow, newData.reqFirmwareOffsetLow)) {
            return true;
        }
        if (!Objects.equals(reqFirmwareOffsetHigh, newData.reqFirmwareOffsetHigh)) {
            return true;
        }
        if (!Objects.equals(reqFirmwareDataLength, newData.reqFirmwareDataLength)) {
            return true;
        }
        // 比较枪头告警状态字
        if (!Objects.equals(gunAlarmSeg1, newData.gunAlarmSeg1)) {
            return true;
        }
        if (!Objects.equals(gunAlarmSeg2, newData.gunAlarmSeg2)) {
            return true;
        }
        if (!Objects.equals(gunAlarmSeg3, newData.gunAlarmSeg3)) {
            return true;
        }
        if (!Objects.equals(gunAlarmSeg4, newData.gunAlarmSeg4)) {
            return true;
        }

        // 比较激光器告警状态字
        if (!Objects.equals(laserAlarmSeg1, newData.laserAlarmSeg1)) {
            return true;
        }
        if (!Objects.equals(laserAlarmSeg2, newData.laserAlarmSeg2)) {
            return true;
        }
        if (!Objects.equals(laserAlarmSeg3, newData.laserAlarmSeg3)) {
            return true;
        }
        if (!Objects.equals(laserAlarmSeg4, newData.laserAlarmSeg4)) {
            return true;
        }

        // 比较送丝机告警状态字
        if (!Objects.equals(wireFeederAlarmSeg1, newData.wireFeederAlarmSeg1)) {
            return true;
        }
        if (!Objects.equals(wireFeederAlarmSeg2, newData.wireFeederAlarmSeg2)) {
            return true;
        }

        // 比较控制卡+机台状态字
        if (!Objects.equals(controlCardAlarmSeg1, newData.controlCardAlarmSeg1)) {
            return true;
        }
        if (!Objects.equals(controlCardAlarmSeg2, newData.controlCardAlarmSeg2)) {
            return true;
        }
        if (!Objects.equals(machineStatusSeg1, newData.machineStatusSeg1)) {
            return true;
        }
        if (!Objects.equals(machineStatusSeg2, newData.machineStatusSeg2)) {
            return true;
        }
        if (!Objects.equals(modbusStatusReadTruncated, newData.modbusStatusReadTruncated)) {
            return true;
        }
        // 忽略预留字段（已标记@Deprecated）

        return false;
    }

    @Override
    public DeviceStatus clone() {
        return GsonUtils.fromJson(GsonUtils.toJson(this), DeviceStatus.class);
    }
}
