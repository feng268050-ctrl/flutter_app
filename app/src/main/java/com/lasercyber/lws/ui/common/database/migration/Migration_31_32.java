package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Drops {@code systemVersion} from {@code t_device_info} (app release comes from APK only).
 */
public class Migration_31_32 extends Migration {
    public Migration_31_32() {
        super(31, 32);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_device_info_new` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "`model` TEXT, `serialNumber` TEXT, `firmwareVersion` TEXT, `gunSn` TEXT, `mainControlSn` TEXT, "
                        + "`laserVersion` TEXT, `laserHardwareVersion` TEXT, `uiVersion` TEXT, `processLibVersion` TEXT, "
                        + "`wireFeederVersion` TEXT, `wireFeederHardwareVersion` TEXT, `gunHeadHardwareVersion` TEXT, "
                        + "`gunHeadSoftwareVersion` TEXT, `AIVersion` TEXT, `deviceSn` TEXT)");
        database.execSQL(
                "INSERT INTO `t_device_info_new` (`id`,`model`,`serialNumber`,`firmwareVersion`,`gunSn`,`mainControlSn`,"
                        + "`laserVersion`,`laserHardwareVersion`,`uiVersion`,`processLibVersion`,`wireFeederVersion`,"
                        + "`wireFeederHardwareVersion`,`gunHeadHardwareVersion`,`gunHeadSoftwareVersion`,`AIVersion`,`deviceSn`) "
                        + "SELECT `id`,`model`,`serialNumber`,`firmwareVersion`,`gunSn`,`mainControlSn`,`laserVersion`,"
                        + "`laserHardwareVersion`,`uiVersion`,`processLibVersion`,`wireFeederVersion`,`wireFeederHardwareVersion`,"
                        + "`gunHeadHardwareVersion`,`gunHeadSoftwareVersion`,`AIVersion`,`deviceSn` FROM `t_device_info`");
        database.execSQL("DROP TABLE `t_device_info`");
        database.execSQL("ALTER TABLE `t_device_info_new` RENAME TO `t_device_info`");
    }
}
