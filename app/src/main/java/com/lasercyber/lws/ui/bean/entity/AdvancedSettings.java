package com.lasercyber.lws.ui.bean.entity;

import androidx.annotation.NonNull;
import androidx.room.ColumnInfo;
import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

/**
 * Advanced Settings page state: Modbus-backed device parameters and app-only toggles.
 */
@Data
@Entity(tableName = "t_advanced_settings")
public class AdvancedSettings {
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
    /** Live-weld lens contamination AI assistance during laser-on sessions (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "1")
    private Boolean lensContaminationDetectionEnabled = true;
    /** Laser-on zero-point offset AI assistance during laser-on sessions (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "1")
    private Boolean zeroPointOffsetDetectionEnabled = true;
    /** Keep laser on during coded alarms while already emitting (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "0")
    private Boolean keepLaserOnWhileAlarmed = false;
    /** Bypass C002 laser-enable blocking while camera comm fault persists (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "0")
    private Boolean allowWorkAfterCameraAlarm = false;
    /** Bypass A001 laser-enable blocking while shielding gas alarm persists (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "0")
    private Boolean allowWorkAfterGasAlarm = false;
    /** Bypass L001 laser-enable blocking while heavy lens contamination episode persists (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "0")
    private Boolean allowWorkAfterLensContamination = false;
    /** Bypass W001/W002 laser-enable blocking while wire feeder alarm persists (app-only, not Modbus). */
    @NonNull
    @ColumnInfo(defaultValue = "0")
    private Boolean allowWorkAfterFeederAlarm = false;
}
