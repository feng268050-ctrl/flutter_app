package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_25_26 extends Migration {
    public Migration_25_26() {
        super(25, 26);
    }
    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL("ALTER TABLE warn_table ADD COLUMN level INTEGER");
    }
}
