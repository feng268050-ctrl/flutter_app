package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Fixes {@code t_common_settings} / {@code t_parameter_settings} created by an earlier
 * {@link Migration_43_44} revision that declared {@code id NOT NULL}, which Room rejects.
 */
public class Migration_44_45 extends Migration {

    public Migration_44_45() {
        super(44, 45);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        recreateCommonSettings(database);
        recreateParameterSettings(database);
    }

    private static void recreateCommonSettings(SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_common_settings_fix` ("
                        + "`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "`language` TEXT, "
                        + "`unit` TEXT, "
                        + "`soundEffect` INTEGER, "
                        + "`showBootSelfCheck` INTEGER NOT NULL DEFAULT 1)");
        database.execSQL(
                "INSERT INTO `t_common_settings_fix` (`id`, `language`, `unit`, `soundEffect`, `showBootSelfCheck`) "
                        + "SELECT `id`, `language`, `unit`, `soundEffect`, `showBootSelfCheck` FROM `t_common_settings`");
        database.execSQL("DROP TABLE `t_common_settings`");
        database.execSQL("ALTER TABLE `t_common_settings_fix` RENAME TO `t_common_settings`");
    }

    private static void recreateParameterSettings(SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_parameter_settings_fix` ("
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
                "INSERT INTO `t_parameter_settings_fix` ("
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
        database.execSQL("ALTER TABLE `t_parameter_settings_fix` RENAME TO `t_parameter_settings`");
    }
}
