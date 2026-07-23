package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Normalizes deprecated engineer custom rows ({@code dataType = 2}) to common presets ({@code dataType = 1}).
 */
public class Migration_41_42 extends Migration {
    public Migration_41_42() {
        super(41, 42);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "UPDATE t_process_parameters_data SET dataType = 1 WHERE dataType = 2");
    }
}
