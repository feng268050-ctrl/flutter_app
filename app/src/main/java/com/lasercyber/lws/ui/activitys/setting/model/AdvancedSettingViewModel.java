package com.lasercyber.lws.ui.activitys.setting.model;

import android.content.Context;
import android.util.Log;

import androidx.lifecycle.LifecycleOwner;

import com.lasercyber.lws.ui.activitys.BaseViewModel;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;
import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.convert.AdvancedSettingConvertUtil;
import com.lasercyber.lws.ui.repository.AdvancedSettingsDao;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;

import java.util.Locale;
import java.util.Objects;
import java.util.function.Consumer;

/**
 * 高级设置viewModel
 */
public class AdvancedSettingViewModel extends BaseViewModel<AdvancedSettingVo> {
    private CommonSettingsDao commonSettingsDao;
    private AdvancedSettingsDao advancedSettingsDao;

    public void init(Context context) {
        AppDatabase instance = AppDatabase.getInstance(context);
        commonSettingsDao = instance.commonSettingsDao();
        advancedSettingsDao = instance.advancedSettingsDao();
        ThreadPoolManager.getExecutor().execute(() -> {
            CommonSettings common = loadOrCreateCommon(context);
            AdvancedSettings parameter = loadOrCreateAdvancedSettings(context);
            AdvancedSettingVo vo = AdvancedSettingConvertUtil.convertToVo(common, parameter);
            AiAssistanceSettings.refreshCacheFromAdvancedSettings(parameter);
            DangerousOperationsSettings.refreshCacheFromAdvancedSettings(parameter);
            super.postLiveData(vo);
        });
    }

    public void observeCommonSettings(LifecycleOwner owner) {
        if (commonSettingsDao == null) {
            return;
        }
        commonSettingsDao.selectOneLiveData().observe(owner, common -> {
            if (common == null) {
                return;
            }
            AdvancedSettingVo vo = getData();
            if (vo == null) {
                return;
            }
            Boolean unitSetting = UnitSystem.fromWireValue(common.getUnit()).toLegacyUnitSetting();
            if (Objects.equals(vo.getUnitSetting(), unitSetting)) {
                return;
            }
            vo.setUnitSetting(unitSetting);
            postLiveData(vo);
        });
    }

    public CommonSettings getCommonSettings(Context context) {
        AppDatabase instance = AppDatabase.getInstance(context);
        commonSettingsDao = instance.commonSettingsDao();
        return loadOrCreateCommon(context);
    }

    /**
     * @deprecated Use {@link #getCommonSettings(Context)} for remote snapshot; parameters via {@link AdvancedSettingsDao}.
     */
    @Deprecated
    public AdvancedSettings getAdvancedSettings(Context context) {
        AppDatabase instance = AppDatabase.getInstance(context);
        advancedSettingsDao = instance.advancedSettingsDao();
        return loadOrCreateAdvancedSettings(context);
    }

    public void updateDataToDb() {
        ThreadPoolManager.getExecutor().execute(() -> {
            AdvancedSettingVo vo = getData();
            if (vo == null) {
                Log.d(TAG, "updateDataToDb: 高级设置更新到数据库失败:null");
                return;
            }
            AdvancedSettings parameter = AdvancedSettingConvertUtil.convertToAdvancedSettings(vo);
            if (parameter != null && parameter.getId() != null) {
                advancedSettingsDao.update(parameter);
            }
        });
    }

    public int getEffect(Context context) {
        AppDatabase instance = AppDatabase.getInstance(context);
        Integer index = instance.commonSettingsDao().selectSoundEffect();
        return index == null ? 0 : index;
    }

    public void updateDataToDb(UpdateCallBack callBack) {
        ThreadPoolManager.getExecutor().execute(() -> {
            AdvancedSettingVo vo = getData();
            if (vo == null) {
                Log.d(TAG, "updateDataToDb: 语言更新到数据库失败:null");
                return;
            }
            AdvancedSettings parameter = AdvancedSettingConvertUtil.convertToAdvancedSettings(vo);
            int updated = 0;
            if (parameter != null && parameter.getId() != null) {
                updated += advancedSettingsDao.update(parameter);
            }
            if (callBack == null) {
                return;
            }
            callBack.accept(updated);
        });
    }

    private CommonSettings loadOrCreateCommon(Context context) {
        if (commonSettingsDao == null) {
            commonSettingsDao = AppDatabase.getInstance(context).commonSettingsDao();
        }
        CommonSettings common = commonSettingsDao.selectOne();
        if (common != null) {
            return common;
        }
        common = DefaultValueUtils.createDefaultCommonSettings();
        Locale locale = SystemSettingUtils.getLanguage();
        if (locale != null && "zh".equalsIgnoreCase(locale.getLanguage())) {
            common.setLanguage(CommonSettingsLanguage.ZH_CN);
        }
        long id = commonSettingsDao.insert(common);
        common.setId((int) id);
        return common;
    }

    private AdvancedSettings loadOrCreateAdvancedSettings(Context context) {
        if (advancedSettingsDao == null) {
            advancedSettingsDao = AppDatabase.getInstance(context).advancedSettingsDao();
        }
        AdvancedSettings parameter = advancedSettingsDao.selectOne();
        if (parameter != null) {
            return parameter;
        }
        parameter = DefaultValueUtils.createDefaultAdvancedSettings();
        long id = advancedSettingsDao.insert(parameter);
        parameter.setId((int) id);
        return parameter;
    }

    public static abstract class UpdateCallBack implements Consumer<Integer> {
        public abstract void accept(Integer integer);
    }
}
