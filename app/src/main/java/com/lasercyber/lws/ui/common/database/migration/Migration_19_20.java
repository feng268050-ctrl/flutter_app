package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_19_20 extends Migration {
    public Migration_19_20() {
        super(19, 20);
    }
    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL("ALTER TABLE t_process_parameters_data ADD COLUMN dataType int");
    }
}
