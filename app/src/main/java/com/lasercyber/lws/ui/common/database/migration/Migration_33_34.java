package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Renames {@code warn_table.newTiem} to {@code newTime} (typo fix). Uses copy/rename for SQLite
 * versions that do not support {@code ALTER TABLE ... RENAME COLUMN}.
 */
public class Migration_33_34 extends Migration {
    public Migration_33_34() {
        super(33, 34);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `warn_table_new` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "`ymdDate` TEXT, `hmDate` TEXT, `code` TEXT, `content` TEXT, `time` INTEGER, "
                        + "`newTime` INTEGER, `level` INTEGER)");
        database.execSQL(
                "INSERT INTO `warn_table_new` (`id`, `ymdDate`, `hmDate`, `code`, `content`, `time`, "
                        + "`newTime`, `level`) SELECT `id`, `ymdDate`, `hmDate`, `code`, `content`, `time`, "
                        + "`newTiem`, `level` FROM `warn_table`");
        database.execSQL("DROP TABLE `warn_table`");
        database.execSQL("ALTER TABLE `warn_table_new` RENAME TO `warn_table`");
    }
}
