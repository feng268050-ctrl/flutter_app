package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Renames {@code syncStatus} to {@code uploadStatus} on {@code t_params_process_video} (SQLite rebuild for minSdk).
 */
public class Migration_37_38 extends Migration {
    public Migration_37_38() {
        super(37, 38);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_params_process_video_new` ("
                        + "`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "
                        + "`videoPath` TEXT, "
                        + "`processData` TEXT, "
                        + "`processType` INTEGER, "
                        + "`materialType` INTEGER, "
                        + "`fileSize` INTEGER NOT NULL, "
                        + "`duration` INTEGER NOT NULL, "
                        + "`createTime` INTEGER, "
                        + "`status` INTEGER, "
                        + "`videoId` TEXT, "
                        + "`resolution` TEXT, "
                        + "`uploadStatus` INTEGER NOT NULL, "
                        + "`uploadProgress` INTEGER NOT NULL, "
                        + "`coverUrl` TEXT, "
                        + "`videoUrl` TEXT"
                        + ")");
        database.execSQL(
                "INSERT INTO `t_params_process_video_new` ("
                        + "`id`, `videoPath`, `processData`, `processType`, `materialType`, "
                        + "`fileSize`, `duration`, `createTime`, `status`, `videoId`, `resolution`, "
                        + "`uploadStatus`, `uploadProgress`, `coverUrl`, `videoUrl`) "
                        + "SELECT "
                        + "`id`, `videoPath`, `processData`, `processType`, `materialType`, "
                        + "`fileSize`, `duration`, `createTime`, `status`, `videoId`, `resolution`, "
                        + "`syncStatus`, `uploadProgress`, `coverUrl`, `videoUrl` "
                        + "FROM `t_params_process_video`");
        database.execSQL("DROP TABLE `t_params_process_video`");
        database.execSQL("ALTER TABLE `t_params_process_video_new` RENAME TO `t_params_process_video`");
    }
}
