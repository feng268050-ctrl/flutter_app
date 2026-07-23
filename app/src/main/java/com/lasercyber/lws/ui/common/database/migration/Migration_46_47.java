package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds AI assistance toggles to {@code t_advanced_settings}.
 */
public class Migration_46_47 extends Migration {

    public Migration_46_47() {
        super(46, 47);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `lensContaminationDetectionEnabled` INTEGER NOT NULL DEFAULT 1");
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `zeroPointOffsetDetectionEnabled` INTEGER NOT NULL DEFAULT 1");
    }
}
