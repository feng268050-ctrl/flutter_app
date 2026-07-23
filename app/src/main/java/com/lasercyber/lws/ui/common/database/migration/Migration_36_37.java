package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Renames {@code materials} to {@code materialType} on {@code t_params_process_video} and adds
 * nullable {@code coverUrl} / {@code videoUrl} (SQLite cannot rename in place reliably across minSdk).
 */
public class Migration_36_37 extends Migration {
    public Migration_36_37() {
        super(36, 37);
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
                        + "`syncStatus` INTEGER NOT NULL, "
                        + "`uploadProgress` INTEGER NOT NULL, "
                        + "`coverUrl` TEXT, "
                        + "`videoUrl` TEXT"
                        + ")");
        database.execSQL(
                "INSERT INTO `t_params_process_video_new` ("
                        + "`id`, `videoPath`, `processData`, `processType`, `materialType`, "
                        + "`fileSize`, `duration`, `createTime`, `status`, `videoId`, `resolution`, "
                        + "`syncStatus`, `uploadProgress`, `coverUrl`, `videoUrl`) "
                        + "SELECT "
                        + "`id`, `videoPath`, `processData`, `processType`, `materials`, "
                        + "`fileSize`, `duration`, `createTime`, `status`, `videoId`, `resolution`, "
                        + "`syncStatus`, `uploadProgress`, NULL, NULL "
                        + "FROM `t_params_process_video`");
        database.execSQL("DROP TABLE `t_params_process_video`");
        database.execSQL("ALTER TABLE `t_params_process_video_new` RENAME TO `t_params_process_video`");
    }
}
