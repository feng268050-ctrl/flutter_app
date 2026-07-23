package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_26_27 extends Migration {
    public Migration_26_27() {
        super(26, 27);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        String createTableSql = "CREATE TABLE IF NOT EXISTS `t_params_process_video` (" +
                "`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL," +
                "`videoPath` TEXT," +
                "`processData` TEXT," +
                "`processType` INTEGER," +
                "`fileSize` INTEGER NOT NULL," +
                "`duration` INTEGER NOT NULL," +
                "`createTime` INTEGER)";
        database.execSQL(createTableSql);
    }
}
