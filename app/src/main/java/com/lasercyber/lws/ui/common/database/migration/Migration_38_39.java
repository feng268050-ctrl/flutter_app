package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Renames {@code processData} → {@code processParametersJson} and drops legacy {@code status}
 * on {@code t_params_process_video} (SQLite rebuild for minSdk).
 */
public class Migration_38_39 extends Migration {
    public Migration_38_39() {
        super(38, 39);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_params_process_video_new` ("
                        + "`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "
                        + "`videoPath` TEXT, "
                        + "`processParametersJson` TEXT, "
                        + "`processType` INTEGER, "
                        + "`materialType` INTEGER, "
                        + "`fileSize` INTEGER NOT NULL, "
                        + "`duration` INTEGER NOT NULL, "
                        + "`createTime` INTEGER, "
                        + "`videoId` TEXT, "
                        + "`resolution` TEXT, "
                        + "`uploadStatus` INTEGER NOT NULL, "
                        + "`uploadProgress` INTEGER NOT NULL, "
                        + "`coverUrl` TEXT, "
                        + "`videoUrl` TEXT"
                        + ")");
        database.execSQL(
                "INSERT INTO `t_params_process_video_new` ("
                        + "`id`, `videoPath`, `processParametersJson`, `processType`, `materialType`, "
                        + "`fileSize`, `duration`, `createTime`, `videoId`, `resolution`, "
                        + "`uploadStatus`, `uploadProgress`, `coverUrl`, `videoUrl`) "
                        + "SELECT "
                        + "`id`, `videoPath`, `processData`, `processType`, `materialType`, "
                        + "`fileSize`, `duration`, `createTime`, `videoId`, `resolution`, "
                        + "`uploadStatus`, `uploadProgress`, `coverUrl`, `videoUrl` "
                        + "FROM `t_params_process_video`");
        database.execSQL("DROP TABLE `t_params_process_video`");
        database.execSQL("ALTER TABLE `t_params_process_video_new` RENAME TO `t_params_process_video`");
    }
}
