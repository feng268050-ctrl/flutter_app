package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_20_21 extends Migration {
    public Migration_20_21() {
        super(20, 21);
    }
    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL("ALTER TABLE t_process_parameters_data ADD COLUMN originId int");
    }
}
