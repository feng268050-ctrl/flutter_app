package com.lasercyber.lws.ui.bean.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

/**
 * Advanced Settings device parameters persisted for Modbus register writes.
 */
@Data
@Entity(tableName = "t_parameter_settings")
public class ParameterSettings {
    @PrimaryKey(autoGenerate = true)
    private Integer id;
    private Double zeroPointCorrection;
    private Double properSwingWidth;
    private Double laserStartPower;
    private Double laserEndPower;
    private Double blowPressureThreshold;
    private Integer redLightOffset;
    private Integer swingSpeedUpperLimit;
    private Integer swingSpeedLowerLimit;
    private Integer manualWireFeedSpeed;
    private Integer manualDrawStringSpeed;
    private Integer inletGasPressureThreshold;
    private Double driverTemperatureAlarmThreshold;
    private Double protectiveLensTemperatureAlarmThreshold;
    private Double collimatingLensTemperatureAlarmThreshold;
    private Double motorTemperatureAlarmThreshold;
    private Double temperatureAlarmRecoveryInterval;
}
