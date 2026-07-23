package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_23_24 extends Migration {
    public Migration_23_24() {
        super(23, 24);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 为t_process_parameters_data表添加gear列（INTEGER类型，允许为null）
        database.execSQL("ALTER TABLE t_process_parameters_data ADD COLUMN gear INTEGER");
    }
}
