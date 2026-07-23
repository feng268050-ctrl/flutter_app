package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds Advanced Settings register fields for 0x009A-0x009F.
 */
public class Migration_40_41 extends Migration {
    public Migration_40_41() {
        super(40, 41);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL("ALTER TABLE `t_advanced_setting` ADD COLUMN `inletGasPressureThreshold` INTEGER");
        database.execSQL("ALTER TABLE `t_advanced_setting` ADD COLUMN `driverTemperatureAlarmThreshold` REAL");
        database.execSQL("ALTER TABLE `t_advanced_setting` ADD COLUMN `protectiveLensTemperatureAlarmThreshold` REAL");
        database.execSQL("ALTER TABLE `t_advanced_setting` ADD COLUMN `collimatingLensTemperatureAlarmThreshold` REAL");
        database.execSQL("ALTER TABLE `t_advanced_setting` ADD COLUMN `motorTemperatureAlarmThreshold` REAL");
        database.execSQL("ALTER TABLE `t_advanced_setting` ADD COLUMN `temperatureAlarmRecoveryInterval` REAL");
    }
}
