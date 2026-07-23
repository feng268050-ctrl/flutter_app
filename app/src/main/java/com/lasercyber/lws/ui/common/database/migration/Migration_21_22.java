package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

public class Migration_21_22 extends Migration {
    public Migration_21_22() {
        super(21, 22);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        // 步骤1：创建临时表（严格匹配Room预期的表结构：id加NOT NULL，字段顺序与日志一致）
        database.execSQL("CREATE TABLE IF NOT EXISTS t_process_parameters_data_temp (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL," + // 关键：补全NOT NULL
                "paramsName TEXT," +
                "materials INTEGER," +
                "thickness REAL," +
                "laserPower INTEGER," +
                "perforationPower INTEGER," +
                "swingFrequency INTEGER," +
                "laserFrequency INTEGER," +
                "perforationFrequency INTEGER," +
                "swingWidth REAL," +
                "blowDelay INTEGER," +
                "closeAirDelay INTEGER," +
                "closeLightDelay INTEGER," +
                "fillDelay INTEGER," +
                "wireFeedingDelay INTEGER," +
                "perforationDuration REAL," +
                "pointWeldingInterval INTEGER," +
                "pointWeldingDuration INTEGER," +
                "powerRampUp INTEGER," +
                "powerRampDown INTEGER," +
                "wireFeedSpeed REAL," +
                "retractLength REAL," +
                "retractSpeed REAL," +
                "fillLength REAL," +
                "laserDutyCycle INTEGER," +
                "perforationDutyCycle INTEGER," +
                "processType INTEGER," +
                "dataType INTEGER," +
                "originId INTEGER" +
                ")");

        // 步骤2：迁移原表数据到临时表（字段顺序与临时表完全一致）
        database.execSQL("INSERT INTO t_process_parameters_data_temp (" +
                "id, paramsName, materials, thickness, laserPower, perforationPower, " +
                "swingFrequency, laserFrequency, perforationFrequency, swingWidth, " +
                "blowDelay, closeAirDelay, closeLightDelay, fillDelay, wireFeedingDelay, " +
                "perforationDuration, pointWeldingInterval, pointWeldingDuration, " +
                "powerRampUp, powerRampDown, wireFeedSpeed, retractLength, retractSpeed, " +
                "fillLength, laserDutyCycle, perforationDutyCycle, processType, dataType, originId) " +
                "SELECT " +
                "id, paramsName, materials, thickness, laserPower, perforationPower, " +
                "swingFrequency, laserFrequency, perforationFrequency, swingWidth, " +
                "blowDelay, closeAirDelay, closeLightDelay, fillDelay, wireFeedingDelay, " +
                "perforationDuration, pointWeldingInterval, pointWeldingDuration, " +
                "powerRampUp, powerRampDown, wireFeedSpeed, retractLength, retractSpeed, " +
                "fillLength, laserDutyCycle, perforationDutyCycle, processType, dataType, originId " +
                "FROM t_process_parameters_data");

        // 步骤3：删除原表
        database.execSQL("DROP TABLE t_process_parameters_data");

        // 步骤4：重命名临时表为原表名
        database.execSQL("ALTER TABLE t_process_parameters_data_temp RENAME TO t_process_parameters_data");
    }
}
