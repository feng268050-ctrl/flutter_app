package com.lasercyber.lws.ui.bean.entity;

import com.lasercyber.lws.ui.bean.ui.DataEquals;

import java.io.Serializable;

import lombok.Data;

/**
 * 告警信息
 */
@Deprecated
@Data
public class WarnInfo implements Serializable , DataEquals<WarnInfo> {
    /**
     * 激光器通信 0-正常 1-告警
     */
    private Integer laserCommunication;
    /**
     * 泵源板温度
     */
    private Double pumpBoardTemperature;
    /**
     * 泵源板温度状态 0-正常 1-告警
     */
    private Integer pumpBoardTemperatureStatus;
    /**
     * 泵源温度
     */
    private Double pumpTemperature;
    /**
     * 泵源温度状态 0-正常 1-告警
     */
    private Integer pumpTemperatureStatus;
    /**
     * 电流报警 0-正常 1-告警
     */
    private Integer currentAlarm;
    /**
     * 红光电流 0-正常 1-告警
     */
    private Double redLightCurrent;
    /**
     * 红光电流状态 0-正常 1-告警
     */
    private Integer redLightCurrentStatus;
    /**
     * 泵源电流 0-正常 1-告警
     */
    @Deprecated
    private Double pumpCurrent;
    /**
     * 泵源电流状态 0-正常 1-告警
     */
    @Deprecated
    private Integer pumpCurrentStatus;
    /**
     * 泵源电压状态 0-正常 1-告警
     */
    private Integer pumpVoltageStatus;
    /**
     * 前向光PD电压
     */
    private Double forwardLightPDVoltage;
    /**
     * 前向光PD电压状态 0-正常 1-告警
     */
    private Integer forwardLightPDVoltageStatus;
    /**
     * 枪头通讯 0-正常 1-告警
     */
    private Integer gunHeadCommunication;
    /**
     * 电机驱动温度
     */
    private Double motorDriveTemperature;
    /**
     * 电机驱动温度状态 0-正常 1-告警
     */
    private Integer motorDriveTemperatureStatus;
    /**
     * 枪头电机温度
     */
    private Double gunMotorTemperature;
    /**
     * 枪头电机温度状态 0-正常 1-告警
     */
    private Integer gunMotorTemperatureStatus;
    /**
     * 环境温度
     */
    private Double environmentTemperature;
    /**
     * 环境温度状态 0-正常 1-告警
     */
    private Integer environmentTemperatureStatus;
    /**
     * 送丝机通讯 0-正常 1-告警
     */
    private Integer wireFeedingCommunication;

    /**
     * 送丝机电流 0-正常 1-告警
     */
    private Integer wireFeedingCurrentStatus;
    /**
     * 保护镜温度
     */
    private Double protectiveCoverTemperature;
    /**
     * 保护镜温度状态 0-正常 1-告警
     */
    private Integer protectiveCoverTemperatureStatus;

    /**
     * collimatorTemperature 聚焦镜侧温
     */
    private Double collimatorTemperature;
    /**
     * collimatorTemperatur聚焦镜侧温状态 0-正常 1-告警
     */
    private Integer collimatorTemperatureStatus;
    /**
     * 枪头电压
     */
    private Integer gunMotorVoltage;

    /**
     * 枪头电流
     */
    private Integer gunMotorCurrent;

    /**
     * 泵源板温度（带℃）
     * @return
     */
    public String getPumpBoardTemperatureText() {
        return pumpBoardTemperature==null ? "" : pumpBoardTemperature + "℃";
    }

    // 泵源温度（带℃）
    public String getPumpTemperatureText() {
        return pumpTemperature==null ? "" : pumpTemperature + "℃";
    }

    // 红光电流（带A）
    public String getRedLightCurrentText() {
        return redLightCurrent==null ? "" : redLightCurrent + "A";
    }

    // 泵源电流（带A）
    public String getPumpCurrentText() {
        return pumpCurrent==null ? "" : pumpCurrent + "A";
    }

    // 前向光PD电压（带V）
    public String getForwardLightPDVoltageText() {
        return forwardLightPDVoltage==null ? "" : forwardLightPDVoltage + "V";
    }

    // 电机驱动温度（带℃）
    public String getMotorDriveTemperatureText() {
        return motorDriveTemperature==null ? "" : motorDriveTemperature + "℃";
    }

    // 环境温度（带℃）
    public String getEnvironmentTemperatureText() {
        return environmentTemperature==null ? "" : environmentTemperature + "℃";
    }

    @Override
    public boolean dataChange(WarnInfo data) {
        return false;
    }
}
