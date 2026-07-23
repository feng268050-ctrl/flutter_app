package com.lasercyber.lws.ui.common.settings;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;

/**
 * In-memory cache for {@code t_common_settings.soundEffect} so click sounds use the
 * persisted effect immediately (no async init race on first tab tap).
 */
public final class SoundEffectSettings {

    private static final String TAG = LogTAGConstant.GlobalSoundManager;
    private static final int EFFECT_COUNT = 3;

    @Nullable
    private static Integer indexOverrideForTest;
    private static volatile boolean cacheLoaded;
    private static volatile int cachedIndex;

    private SoundEffectSettings() {
    }

    public static void warmCache(Context context) {
        ThreadPoolManager.getExecutor().execute(
                () -> refreshCacheFromDatabase(context.getApplicationContext()));
    }

    public static int getIndex(Context context) {
        if (indexOverrideForTest != null) {
            return clamp(indexOverrideForTest);
        }
        if (!cacheLoaded) {
            return getIndexBlocking(context);
        }
        return cachedIndex;
    }

    public static int getIndexBlocking(Context context) {
        if (indexOverrideForTest != null) {
            return clamp(indexOverrideForTest);
        }
        refreshCacheFromDatabase(context.getApplicationContext());
        return cachedIndex;
    }

    public static void setIndex(Context context, int index) {
        int clamped = clamp(index);
        if (indexOverrideForTest != null) {
            indexOverrideForTest = clamped;
            cachedIndex = clamped;
            cacheLoaded = true;
            return;
        }
        cachedIndex = clamped;
        cacheLoaded = true;
        Context appContext = context.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            CommonSettings settings = loadOrCreate(appContext);
            settings.setSoundEffect(clamped);
            AppDatabase.getInstance(appContext).commonSettingsDao().update(settings);
        });
    }

    private static synchronized void refreshCacheFromDatabase(Context context) {
        try {
            CommonSettings settings = loadOrCreate(context);
            cachedIndex = clamp(settings.getSoundEffect());
            cacheLoaded = true;
        } catch (RuntimeException exception) {
            Log.e(TAG, "Failed to load sound effect; using default index 0", exception);
            cachedIndex = 0;
            cacheLoaded = true;
        }
    }

    private static CommonSettings loadOrCreate(Context context) {
        CommonSettingsDao dao = AppDatabase.getInstance(context).commonSettingsDao();
        CommonSettings settings = dao.selectOne();
        if (settings != null) {
            return settings;
        }
        settings = DefaultValueUtils.createDefaultCommonSettings();
        long id = dao.insert(settings);
        settings.setId((int) id);
        return settings;
    }

    private static int clamp(@Nullable Integer index) {
        if (index == null) {
            return 0;
        }
        if (index < 0 || index >= EFFECT_COUNT) {
            return 0;
        }
        return index;
    }

    static void setIndexOverrideForTest(@Nullable Integer index) {
        indexOverrideForTest = index;
        if (index != null) {
            cachedIndex = clamp(index);
            cacheLoaded = true;
        }
    }

    static void resetForTest() {
        indexOverrideForTest = null;
        cacheLoaded = false;
        cachedIndex = 0;
    }
}
