package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Drops legacy test and work-info tables no longer mapped by Room entities.
 */
public class Migration_50_51 extends Migration {

    public Migration_50_51() {
        super(50, 51);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL("DROP TABLE IF EXISTS `t_device_test`");
        database.execSQL("DROP TABLE IF EXISTS `t_work_info`");
    }
}
