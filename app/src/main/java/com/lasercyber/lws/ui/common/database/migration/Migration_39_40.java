package com.lasercyber.lws.ui.common.database.migration;

import androidx.annotation.NonNull;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

/**
 * Renames {@code paramsName}→{@code name}, {@code materials}→{@code materialType},
 * {@code materialsName}→{@code materialName} on {@code t_process_parameters_data}
 * (table rebuild for broad SQLite compatibility).
 */
public class Migration_39_40 extends Migration {
    public Migration_39_40() {
        super(39, 40);
    }

    @Override
    public void migrate(@NonNull SupportSQLiteDatabase database) {
        database.execSQL(
                "CREATE TABLE IF NOT EXISTS `t_process_parameters_data_new` ("
                        + "`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
                        + "`name` TEXT, "
                        + "`materialType` INTEGER, "
                        + "`materialName` TEXT, "
                        + "`thickness` REAL, "
                        + "`laserPower` INTEGER, "
                        + "`perforationPower` INTEGER, "
                        + "`swingFrequency` INTEGER, "
                        + "`laserFrequency` INTEGER, "
                        + "`perforationFrequency` INTEGER, "
                        + "`swingWidth` REAL, "
                        + "`blowDelay` INTEGER, "
                        + "`closeAirDelay` INTEGER, "
                        + "`closeLightDelay` INTEGER, "
                        + "`fillDelay` INTEGER, "
                        + "`wireFeedingDelay` INTEGER, "
                        + "`perforationDuration` REAL, "
                        + "`pointWeldingInterval` INTEGER, "
                        + "`pointWeldingDuration` INTEGER, "
                        + "`powerRampUp` INTEGER, "
                        + "`powerRampDown` INTEGER, "
                        + "`wireFeedSpeed` REAL, "
                        + "`retractLength` REAL, "
                        + "`retractSpeed` REAL, "
                        + "`fillLength` REAL, "
                        + "`laserDutyCycle` INTEGER, "
                        + "`perforationDutyCycle` INTEGER, "
                        + "`processType` INTEGER, "
                        + "`dataType` INTEGER, "
                        + "`originId` INTEGER, "
                        + "`gear` INTEGER"
                        + ")");
        database.execSQL(
                "INSERT INTO `t_process_parameters_data_new` ("
                        + "`id`, `name`, `materialType`, `materialName`, `thickness`, `laserPower`, `perforationPower`, "
                        + "`swingFrequency`, `laserFrequency`, `perforationFrequency`, `swingWidth`, `blowDelay`, "
                        + "`closeAirDelay`, `closeLightDelay`, `fillDelay`, `wireFeedingDelay`, `perforationDuration`, "
                        + "`pointWeldingInterval`, `pointWeldingDuration`, `powerRampUp`, `powerRampDown`, "
                        + "`wireFeedSpeed`, `retractLength`, `retractSpeed`, `fillLength`, `laserDutyCycle`, "
                        + "`perforationDutyCycle`, `processType`, `dataType`, `originId`, `gear`) "
                        + "SELECT "
                        + "`id`, `paramsName`, `materials`, `materialsName`, `thickness`, `laserPower`, `perforationPower`, "
                        + "`swingFrequency`, `laserFrequency`, `perforationFrequency`, `swingWidth`, `blowDelay`, "
                        + "`closeAirDelay`, `closeLightDelay`, `fillDelay`, `wireFeedingDelay`, `perforationDuration`, "
                        + "`pointWeldingInterval`, `pointWeldingDuration`, `powerRampUp`, `powerRampDown`, "
                        + "`wireFeedSpeed`, `retractLength`, `retractSpeed`, `fillLength`, `laserDutyCycle`, "
                        + "`perforationDutyCycle`, `processType`, `dataType`, `originId`, `gear` "
                        + "FROM `t_process_parameters_data`");
        database.execSQL("DROP TABLE `t_process_parameters_data`");
        database.execSQL("ALTER TABLE `t_process_parameters_data_new` RENAME TO `t_process_parameters_data`");
    }
}
