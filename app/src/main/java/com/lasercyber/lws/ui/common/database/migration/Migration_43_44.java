package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Splits {@code t_advanced_setting} into {@code t_common_settings} and {@code t_parameter_settings}.
 */
public class Migration_43_44 extends Migration {

    public Migration_43_44() {
        super(43, 44);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_common_settings` ("
                        + "`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "`language` TEXT, "
                        + "`unit` TEXT, "
                        + "`soundEffect` INTEGER, "
                        + "`showBootSelfCheck` INTEGER NOT NULL DEFAULT 1)");
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_parameter_settings` ("
                        + "`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "`zeroPointCorrection` REAL, "
                        + "`properSwingWidth` REAL, "
                        + "`laserStartPower` REAL, "
                        + "`laserEndPower` REAL, "
                        + "`blowPressureThreshold` REAL, "
                        + "`redLightOffset` INTEGER, "
                        + "`swingSpeedUpperLimit` INTEGER, "
                        + "`swingSpeedLowerLimit` INTEGER, "
                        + "`manualWireFeedSpeed` INTEGER, "
                        + "`manualDrawStringSpeed` INTEGER, "
                        + "`inletGasPressureThreshold` INTEGER, "
                        + "`driverTemperatureAlarmThreshold` REAL, "
                        + "`protectiveLensTemperatureAlarmThreshold` REAL, "
                        + "`collimatingLensTemperatureAlarmThreshold` REAL, "
                        + "`motorTemperatureAlarmThreshold` REAL, "
                        + "`temperatureAlarmRecoveryInterval` REAL)");

        database.execSQL(
                "INSERT INTO `t_common_settings` (`language`, `unit`, `soundEffect`, `showBootSelfCheck`) "
                        + "SELECT "
                        + "CASE WHEN `languageSetting` IN ('zh', 'zh-CN') THEN 'zh-CN' ELSE 'en-US' END, "
                        + "CASE WHEN `unitSetting` IS NULL OR `unitSetting` != 0 THEN 'metric' ELSE 'imperial' END, "
                        + "COALESCE(`voiceCheck`, 0), "
                        + "COALESCE(`showBootSelfCheck`, 1) "
                        + "FROM `t_advanced_setting` ORDER BY `id` DESC LIMIT 1");

        database.execSQL(
                "INSERT INTO `t_parameter_settings` ("
                        + "`zeroPointCorrection`, `properSwingWidth`, `laserStartPower`, `laserEndPower`, "
                        + "`blowPressureThreshold`, `redLightOffset`, `swingSpeedUpperLimit`, `swingSpeedLowerLimit`, "
                        + "`manualWireFeedSpeed`, `manualDrawStringSpeed`, `inletGasPressureThreshold`, "
                        + "`driverTemperatureAlarmThreshold`, `protectiveLensTemperatureAlarmThreshold`, "
                        + "`collimatingLensTemperatureAlarmThreshold`, `motorTemperatureAlarmThreshold`, "
                        + "`temperatureAlarmRecoveryInterval`) "
                        + "SELECT "
                        + "`zeroPointCorrection`, `properSwingWidth`, `laserStartPower`, `laserEndPower`, "
                        + "`blowPressureThreshold`, `redLightOffset`, `swingSpeedUpperLimit`, `swingSpeedLowerLimit`, "
                        + "`manualWireFeedSpeed`, `manualDrawStringSpeed`, `inletGasPressureThreshold`, "
                        + "`driverTemperatureAlarmThreshold`, `protectiveLensTemperatureAlarmThreshold`, "
                        + "`collimatingLensTemperatureAlarmThreshold`, `motorTemperatureAlarmThreshold`, "
                        + "`temperatureAlarmRecoveryInterval` "
                        + "FROM `t_advanced_setting` ORDER BY `id` DESC LIMIT 1");

        database.execSQL("DROP TABLE IF EXISTS `t_advanced_setting`");
    }
}
