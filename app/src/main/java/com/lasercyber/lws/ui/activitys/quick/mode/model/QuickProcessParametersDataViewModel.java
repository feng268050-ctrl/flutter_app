package com.lasercyber.lws.ui.activitys.quick.mode.model;

import android.content.Context;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.Transformations;
import androidx.lifecycle.ViewModel;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.upgrade.QuickModeProcessRowSort;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.repository.AdvancedSettingsDao;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;

import java.util.List;

import androidx.annotation.Nullable;

import lombok.Getter;

public class QuickProcessParametersDataViewModel extends ViewModel {
    private static final double QUICK_MODE_LASER_END_POWER_RATIO = 0.97;

    private ProcessParametersDataDao processParametersDataDao;
    private AdvancedSettingsDao advancedSettingsDao;
    @Getter
    private LiveData<List<ProcessParametersData>> listLiveData;
    private LiveData<Boolean> useMMUnit;
    private LiveData<CommonSettings> commonSettingsLiveData;
    private LiveData<AdvancedSettings> parameterSettingsLiveData;

    @Getter
    private Integer type;

    public void init(Context context, Integer type) {
        this.type = type;
        AppDatabase appDataBase = AppDatabase.getInstance(context);
        processParametersDataDao = appDataBase.processParametersDataDao();

        CommonSettingsDao commonSettingsDao = appDataBase.commonSettingsDao();
        advancedSettingsDao = appDataBase.advancedSettingsDao();

        commonSettingsLiveData = commonSettingsDao.selectOneLiveData();
        parameterSettingsLiveData = advancedSettingsDao.selectOneLiveData();
        useMMUnit = Transformations.map(commonSettingsLiveData, QuickProcessParametersDataViewModel::resolveUseMMUnit);
        listLiveData = Transformations.map(
                processParametersDataDao.listAllMaterials(type, ProcessDataType.QUICK_MODE_DATA),
                rows -> rows == null ? null : QuickModeProcessRowSort.sortedCopy(rows, type)
        );
    }

    public LiveData<Boolean> getUseMMUnit() {
        return useMMUnit;
    }

    public boolean useMMUnit() {
        if (useMMUnit == null) {
            return true;
        }
        Boolean value = useMMUnit.getValue();
        return value == null || value;
    }

    private static boolean resolveUseMMUnit(CommonSettings settings) {
        return settings == null
                || settings.getUnit() == null
                || UnitSystem.fromWireValue(settings.getUnit()) == UnitSystem.METRIC;
    }

    public AdvancedSettings getParameterSettingsData() {
        if (parameterSettingsLiveData == null) {
            return null;
        }
        return parameterSettingsLiveData.getValue();
    }

    /**
     * 快速模式开激光时下发高级设置：不校验功率区间，终止功率按当前工艺功率 × 0.97 写 Modbus。
     * Room 读取在后台线程执行，避免主线程访问数据库崩溃。
     */
    public void sendAdvanceSettingForLaserEnable(@Nullable Integer laserPower) {
        ThreadPoolManager.getExecutor().execute(() -> {
            AdvancedSettings settings = resolveAdvancedSettingsBlocking();
            if (laserPower != null) {
                settings.setLaserEndPower(laserPower * QUICK_MODE_LASER_END_POWER_RATIO);
            }
            ModbusManagerRtu.get().writeRegisters(
                    ModbusFiledBuilder.doCreateWriteDeviceSetting(settings));
        });
    }

    private AdvancedSettings resolveAdvancedSettingsBlocking() {
        if (parameterSettingsLiveData != null) {
            AdvancedSettings cached = parameterSettingsLiveData.getValue();
            if (cached != null) {
                return cached;
            }
        }
        if (advancedSettingsDao != null) {
            AdvancedSettings fromDb = advancedSettingsDao.selectOne();
            if (fromDb != null) {
                return fromDb;
            }
        }
        return DefaultValueUtils.createDefaultAdvancedSettings();
    }
}
