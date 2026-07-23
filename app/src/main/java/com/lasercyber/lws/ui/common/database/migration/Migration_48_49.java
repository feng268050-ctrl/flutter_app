package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds keep-laser-on-while-alarmed toggle to {@code t_advanced_settings}.
 */
public class Migration_48_49 extends Migration {

    public Migration_48_49() {
        super(48, 49);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "ALTER TABLE `t_advanced_settings` "
                        + "ADD COLUMN `keepLaserOnWhileAlarmed` INTEGER NOT NULL DEFAULT 0");
    }
}
