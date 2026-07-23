package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_29_30 extends Migration {
    public Migration_29_30() {
        super(29, 30);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        String alterSql = "ALTER TABLE t_params_process_video ADD COLUMN status INTEGER DEFAULT 0";
        database.execSQL(alterSql);
    }
}
