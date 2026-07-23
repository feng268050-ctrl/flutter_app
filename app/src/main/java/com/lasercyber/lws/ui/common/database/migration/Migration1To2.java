package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * 数据库迁移脚本示例
 */
public class Migration1To2 extends Migration {
    /**
     * 从1==>2 的迁移脚本
     */
    public Migration1To2() {
        super(1, 2);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 执行表结构修改sql
        database.execSQL("");
    }
}
