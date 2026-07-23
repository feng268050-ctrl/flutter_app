package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds safety ground lock alarm prompt toggle to {@code t_common_settings}.
 */
public class Migration_49_50 extends Migration {

    public Migration_49_50() {
        super(49, 50);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "ALTER TABLE `t_common_settings` "
                        + "ADD COLUMN `showSafetyGroundLockAlarm` INTEGER NOT NULL DEFAULT 0");
    }
}
