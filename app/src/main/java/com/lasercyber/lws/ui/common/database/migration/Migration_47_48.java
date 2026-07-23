package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds dangerous-operations toggles to {@code t_advanced_settings}.
 */
public class Migration_47_48 extends Migration {

    public Migration_47_48() {
        super(47, 48);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `allowWorkAfterCameraAlarm` INTEGER NOT NULL DEFAULT 0");
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `allowWorkAfterGasAlarm` INTEGER NOT NULL DEFAULT 0");
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `allowWorkAfterLensContamination` INTEGER NOT NULL DEFAULT 0");
    }
}
