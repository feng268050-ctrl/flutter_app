package com.lasercyber.lws.ui.common.database.migration;

import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_18_19 extends Migration {
    public Migration_18_19() {
        super(18, 19);
    }
    @Override
    public void migrate(SupportSQLiteDatabase database) {
        // 为表添加name字段，设置默认值为空字符串以避免非空约束问题
        database.execSQL("ALTER TABLE t_process_parameters_data ADD COLUMN paramsName TEXT");
    }
}
