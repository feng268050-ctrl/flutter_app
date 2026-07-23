package com.lasercyber.lws.ui.common.database;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.CommonUseConsumable;
import com.lasercyber.lws.ui.bean.entity.CustomLayout;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.EngineerCutting;
import com.lasercyber.lws.ui.bean.entity.EngineerWash;
import com.lasercyber.lws.ui.bean.entity.EngineerWelding;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.common.constant.DatabaseConstant;
import com.lasercyber.lws.ui.common.database.migration.Migration_19_20;
import com.lasercyber.lws.ui.common.database.migration.Migration_20_21;
import com.lasercyber.lws.ui.common.database.migration.Migration_22_23;
import com.lasercyber.lws.ui.common.database.migration.Migration_23_24;
import com.lasercyber.lws.ui.common.database.migration.Migration_24_25;
import com.lasercyber.lws.ui.common.database.migration.Migration_25_26;
import com.lasercyber.lws.ui.common.database.migration.Migration_26_27;
import com.lasercyber.lws.ui.common.database.migration.Migration_27_28;
import com.lasercyber.lws.ui.common.database.migration.Migration_28_29;
import com.lasercyber.lws.ui.common.database.migration.Migration_29_30;
import com.lasercyber.lws.ui.common.database.migration.Migration_30_31;
import com.lasercyber.lws.ui.common.database.migration.Migration_31_32;
import com.lasercyber.lws.ui.common.database.migration.Migration_32_33;
import com.lasercyber.lws.ui.common.database.migration.Migration_33_34;
import com.lasercyber.lws.ui.common.database.migration.Migration_34_35;
import com.lasercyber.lws.ui.common.database.migration.Migration_35_36;
import com.lasercyber.lws.ui.common.database.migration.Migration_36_37;
import com.lasercyber.lws.ui.common.database.migration.Migration_37_38;
import com.lasercyber.lws.ui.common.database.migration.Migration_38_39;
import com.lasercyber.lws.ui.common.database.migration.Migration_39_40;
import com.lasercyber.lws.ui.common.database.migration.Migration_40_41;
import com.lasercyber.lws.ui.common.database.migration.Migration_41_42;
import com.lasercyber.lws.ui.common.database.migration.Migration_42_43;
import com.lasercyber.lws.ui.common.database.migration.Migration_43_44;
import com.lasercyber.lws.ui.common.database.migration.Migration_44_45;
import com.lasercyber.lws.ui.common.database.migration.Migration_45_46;
import com.lasercyber.lws.ui.common.database.migration.Migration_46_47;
import com.lasercyber.lws.ui.common.database.migration.Migration_47_48;
import com.lasercyber.lws.ui.common.database.migration.Migration_48_49;
import com.lasercyber.lws.ui.common.database.migration.Migration_49_50;
import com.lasercyber.lws.ui.common.database.migration.Migration_50_51;
import com.lasercyber.lws.ui.common.database.migration.Migration_51_52;
import com.lasercyber.lws.ui.repository.AdvancedSettingsDao;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;
import com.lasercyber.lws.ui.repository.CommonUseConsumableDao;
import com.lasercyber.lws.ui.repository.CustomLayoutDao;
import com.lasercyber.lws.ui.repository.DeviceInfoDto;
import com.lasercyber.lws.ui.repository.EngineerCuttingDto;
import com.lasercyber.lws.ui.repository.EngineerWashDao;
import com.lasercyber.lws.ui.repository.EngineerWeldingDao;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;
import com.lasercyber.lws.ui.repository.StaticDataDao;
import com.lasercyber.lws.ui.repository.WarnTableDao;

/**
 * room基础配置
 */

@Database(
        entities = {
                EngineerWelding.class,
                EngineerWash.class,
                EngineerCutting.class,
                CommonSettings.class,
                AdvancedSettings.class,
                DeviceInfo.class,
                StaticData.class,
                CommonUseConsumable.class,
                WarnTable.class,
                ProcessParametersData.class,
                CustomLayout.class,
                ProcessParamsVideo.class
        },
        version = 52)
public abstract class AppDatabase extends RoomDatabase {
    private static volatile AppDatabase INSTANCE;

    public abstract WarnTableDao warnTableDao();

    public abstract CustomLayoutDao customLayoutDao();

    /*计时计量数据存储*/
    public abstract StaticDataDao staticDataDao();

    /*常用耗材数据存储*/
    public abstract CommonUseConsumableDao commonUseConsumableDao();
    /**
     * 工程师模式，焊接数据存储
     *
     * @return
     */
    public abstract EngineerWeldingDao engineerWeldingDao();

    /**
     * 工程师模式，清洗数据存储
     *
     * @return
     */
    public abstract EngineerWashDao engineerWashDao();

    /**
     * 工程师模式，切割数据存储
     *
     * @return
     */
    public abstract EngineerCuttingDto engineerCuttingDto();

    public abstract CommonSettingsDao commonSettingsDao();

    public abstract AdvancedSettingsDao advancedSettingsDao();
    /**
     * 设备信息数据存储
     * @return
     */
    public abstract DeviceInfoDto deviceInfoDto();

    /**
     * 工艺参数存储
     * @return
     */
    public abstract ProcessParametersDataDao processParametersDataDao();

    public static AppDatabase getInstance(Context context) {
        if (INSTANCE == null) {
            synchronized (AppDatabase.class) {
                if (INSTANCE == null) {
//                    // 获取应用内部存储的 files 目录
//                    File internalDir = new File("/mjdata");
//
//                    // 创建文件夹（若不存在）
//                    if (!internalDir.exists()) {
//                        boolean isCreated = internalDir.mkdirs(); // mkdirs() 可创建多级目录
//                        if (isCreated) {
//                            Log.d("CreateDir", "内部存储文件夹创建成功：" + internalDir.getAbsolutePath());
//                        } else {
//                            Log.e("CreateDir", "内部存储文件夹创建失败");
//                        }
//                    } else {
//                        Log.d("CreateDir", "内部存储文件夹已存在");
//                    }
                    INSTANCE = Room.databaseBuilder(context.getApplicationContext(),
                                    AppDatabase.class,
                                    DatabaseConstant.DATABASE_NAME
                            )
                            // 后续添加迁移脚本
                            // 示例
//                            .addMigrations(new Migration1To2())
//                            .addMigrations(new Migration_18_19())
                            .addMigrations(new Migration_19_20())
                            .addMigrations(new Migration_20_21())
//                            .addMigrations(new Migration_21_22())
                            .addMigrations(new Migration_22_23())
                            .addMigrations(new Migration_23_24())
                            .addMigrations(new Migration_24_25())
                            .addMigrations(new Migration_25_26())
                            .addMigrations(new Migration_26_27())
                            .addMigrations(new Migration_27_28())
                            .addMigrations(new Migration_28_29())
                            .addMigrations(new Migration_29_30())
                            .addMigrations(new Migration_30_31())
                            .addMigrations(new Migration_31_32())
                            .addMigrations(new Migration_32_33())
                            .addMigrations(new Migration_33_34())
                            .addMigrations(new Migration_34_35())
                            .addMigrations(new Migration_35_36())
                            .addMigrations(new Migration_36_37())
                            .addMigrations(new Migration_37_38())
                            .addMigrations(new Migration_38_39())
                            .addMigrations(new Migration_39_40())
                            .addMigrations(new Migration_40_41())
                            .addMigrations(new Migration_41_42())
                            .addMigrations(new Migration_42_43())
                            .addMigrations(new Migration_43_44())
                            .addMigrations(new Migration_44_45())
                            .addMigrations(new Migration_45_46())
                            .addMigrations(new Migration_46_47())
                            .addMigrations(new Migration_47_48())
                            .addMigrations(new Migration_48_49())
                            .addMigrations(new Migration_49_50())
                            .addMigrations(new Migration_50_51())
                            .addMigrations(new Migration_51_52())
                            // APK downgrade (e.g. device DB v45 + app v43): rebuild schema instead of crashing.
                            .fallbackToDestructiveMigrationOnDowngrade()
                            .build();
                }
            }
        }
        return INSTANCE;
    }

    /**
     * 工艺视频存储
     *
     * @return
     */
    public abstract ProcessProcessVideoDao processProcessVideoDao();
}