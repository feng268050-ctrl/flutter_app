package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.bean.ui.DataEquals;

import java.io.Serializable;
import java.util.Objects;

import lombok.Data;

@Data
@Deprecated
public class MachineStatus implements Serializable, DataEquals<MachineStatus> {
    /**
     * 泵源电流 TODO 设备端暂时无法获取
     */
    @Deprecated
    private Double pumpCurrent;
    /**
     * 吹气气压
     */
    private Double blowingAirPressure;
    /**
     * 激光状态
     */
    private Integer laserStatus;
    /**
     * 吹气
     */
    private Integer blowStatus;
    /**
     * 安全锁
     */
    private Integer safetyLockStatus;
    /**
     * 枪头开关
     */
    private Integer gunHeadStatus;
    /**
     * 红光
     */
    private Integer redLightStatus;
    /**
     * 送丝
     */
    private Integer wireFeedingStatus;

    /**
     * 气阀状态 0-关闭 1-开启
     */
    private Integer gasValveStatus;

    /**
     * 钥匙开关 0-未使能 1-使能
     */
    private Integer keySwitchStatus;

    /**
     * 急停开关 0-急停断开 1-急停按下
     */
    private Integer emergencyStopStatus;
    /**
     * 安全门  0-异常 1-正常
     */
    private Integer safetyDoorStatus;
    /**
     * 对比数据是否变化
     * @param data 新数据
     * @return
     */
    @Override
    public boolean dataChange(MachineStatus data) {
        if (data == null) {
            return true;
        }
        // 比较泵源电流
        if (!Objects.equals(this.pumpCurrent, data.pumpCurrent)) {
            return true;
        }
        // 比较吹气气压
        if (!Objects.equals(this.blowingAirPressure, data.blowingAirPressure)) {
            return true;
        }
        // 比较激光状态
        if (!Objects.equals(this.laserStatus, data.laserStatus)) {
            return true;
        }
        // 比较吹气状态
        if (!Objects.equals(this.blowStatus, data.blowStatus)) {
            return true;
        }
        // 比较安全锁状态
        if (!Objects.equals(this.safetyLockStatus, data.safetyLockStatus)) {
            return true;
        }
        // 比较枪头开关状态
        if (!Objects.equals(this.gunHeadStatus, data.gunHeadStatus)) {
            return true;
        }
        // 比较红光状态
        if (!Objects.equals(this.redLightStatus, data.redLightStatus)) {
            return true;
        }
        // 比较送丝状态
        if (!Objects.equals(this.wireFeedingStatus, data.wireFeedingStatus)) {
            return true;
        }
        // 所有字段都相同
        return false;
    }
}
