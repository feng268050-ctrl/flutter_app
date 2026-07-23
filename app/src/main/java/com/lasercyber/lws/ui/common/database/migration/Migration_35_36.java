package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Adds video metadata sync columns to {@code t_params_process_video}.
 */
public class Migration_35_36 extends Migration {
    public Migration_35_36() {
        super(35, 36);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL("ALTER TABLE t_params_process_video ADD COLUMN videoId TEXT");
        database.execSQL("ALTER TABLE t_params_process_video ADD COLUMN resolution TEXT");
        database.execSQL(
                "ALTER TABLE t_params_process_video ADD COLUMN syncStatus INTEGER NOT NULL DEFAULT 0");
        database.execSQL(
                "ALTER TABLE t_params_process_video ADD COLUMN uploadProgress INTEGER NOT NULL DEFAULT 0");
    }
}
