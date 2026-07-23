package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_27_28 extends Migration {
    public Migration_27_28() {
        super(27, 28);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 为t_params_process_video表新增materials字段（Integer类型对应SQLite的INTEGER）
        database.execSQL("ALTER TABLE t_params_process_video ADD COLUMN materials INTEGER");
    }
}
