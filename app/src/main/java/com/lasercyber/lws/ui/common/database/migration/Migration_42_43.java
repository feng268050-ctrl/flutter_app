package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds {@code showBootSelfCheck} to advanced settings for startup self-check preference.
 */
public class Migration_42_43 extends Migration {
    public Migration_42_43() {
        super(42, 43);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "ALTER TABLE `t_advanced_setting` ADD COLUMN `showBootSelfCheck` INTEGER NOT NULL DEFAULT 1");
    }
}
