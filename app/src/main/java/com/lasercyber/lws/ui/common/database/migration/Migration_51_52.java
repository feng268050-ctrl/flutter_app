package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds {@code allowWorkAfterFeederAlarm} to {@code t_advanced_settings}.
 */
public class Migration_51_52 extends Migration {

    public Migration_51_52() {
        super(51, 52);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `allowWorkAfterFeederAlarm` INTEGER NOT NULL DEFAULT 0");
    }
}
