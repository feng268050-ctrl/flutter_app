package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Moves Advanced Settings device parameters from t_parameter_settings to t_advanced_settings.
 */
public class Migration_45_46 extends Migration {

    public Migration_45_46() {
        super(45, 46);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_advanced_settings` ("
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
                "INSERT INTO `t_advanced_settings` ("
                        + "`id`, `zeroPointCorrection`, `properSwingWidth`, `laserStartPower`, `laserEndPower`, "
                        + "`blowPressureThreshold`, `redLightOffset`, `swingSpeedUpperLimit`, `swingSpeedLowerLimit`, "
                        + "`manualWireFeedSpeed`, `manualDrawStringSpeed`, `inletGasPressureThreshold`, "
                        + "`driverTemperatureAlarmThreshold`, `protectiveLensTemperatureAlarmThreshold`, "
                        + "`collimatingLensTemperatureAlarmThreshold`, `motorTemperatureAlarmThreshold`, "
                        + "`temperatureAlarmRecoveryInterval`) "
                        + "SELECT "
                        + "`id`, `zeroPointCorrection`, `properSwingWidth`, `laserStartPower`, `laserEndPower`, "
                        + "`blowPressureThreshold`, `redLightOffset`, `swingSpeedUpperLimit`, `swingSpeedLowerLimit`, "
                        + "`manualWireFeedSpeed`, `manualDrawStringSpeed`, `inletGasPressureThreshold`, "
                        + "`driverTemperatureAlarmThreshold`, `protectiveLensTemperatureAlarmThreshold`, "
                        + "`collimatingLensTemperatureAlarmThreshold`, `motorTemperatureAlarmThreshold`, "
                        + "`temperatureAlarmRecoveryInterval` "
                        + "FROM `t_parameter_settings`");
        database.execSQL("DROP TABLE `t_parameter_settings`");
    }
}
