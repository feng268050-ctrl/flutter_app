package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_30_31 extends Migration {
    public Migration_30_31() {
        super(30, 31);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 1. 新增deviceSn字段：TEXT类型（字符串），允许为空，默认值为空字符串（可根据需求调整）
        String alterDeviceSnSql = "ALTER TABLE t_device_info ADD COLUMN deviceSn TEXT DEFAULT ''";
        database.execSQL(alterDeviceSnSql);

        // 2. 新增AIVersion字段：INTEGER类型，允许为空，默认值0（保留可空特性，不加NOT NULL）
        String alterAIVersionSql = "ALTER TABLE t_device_info ADD COLUMN AIVersion TEXT DEFAULT '1.0'";
        database.execSQL(alterAIVersionSql);
    }
}
