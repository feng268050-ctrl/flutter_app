package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_22_23 extends Migration {
    public Migration_22_23() {
        super(22, 23);
    }
    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 字段类型为TEXT（对应Java中的String），允许为NULL
        database.execSQL("ALTER TABLE t_process_parameters_data ADD COLUMN materialsName TEXT");
    }
}
