package com.lasercyber.lws.ui.common.settings;

import android.content.Context;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;

import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Reads and writes the safety ground lock alarm prompt preference from
 * {@code t_common_settings.showSafetyGroundLockAlarm}.
 */
public final class SafetyGroundLockAlarmSettings {

    private static final String TAG = "SafetyGroundLockAlarm";
    private static final long CACHE_LOAD_TIMEOUT_MS = 2_000L;

    @Nullable
    private static Boolean enabledOverrideForTest;
    private static volatile boolean cacheLoaded;
    private static volatile boolean cachedEnabled;

    private SafetyGroundLockAlarmSettings() {
    }

    public static void warmCache(Context context) {
        ThreadPoolManager.getExecutor().execute(() -> refreshCacheFromDatabase(context.getApplicationContext()));
    }

    public static boolean isEnabled(@Nullable Context context) {
        if (enabledOverrideForTest != null) {
            return enabledOverrideForTest;
        }
        if (!cacheLoaded) {
            ensureCacheLoaded(context != null ? context.getApplicationContext() : null);
        }
        return cachedEnabled;
    }

    public static void setEnabled(Context context, boolean enabled) {
        if (enabledOverrideForTest != null) {
            enabledOverrideForTest = enabled;
            cachedEnabled = enabled;
            cacheLoaded = true;
            return;
        }
        cachedEnabled = enabled;
        cacheLoaded = true;
        Context appContext = context.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            CommonSettings settings = loadOrCreate(appContext);
            settings.setShowSafetyGroundLockAlarm(enabled);
            AppDatabase.getInstance(appContext).commonSettingsDao().update(settings);
        });
    }

    private static void ensureCacheLoaded(@Nullable Context context) {
        if (cacheLoaded || context == null) {
            return;
        }
        if (Looper.getMainLooper().isCurrentThread()) {
            awaitCacheFromDatabase(context);
            return;
        }
        refreshCacheFromDatabase(context);
    }

    private static void awaitCacheFromDatabase(@NonNull Context context) {
        CountDownLatch latch = new CountDownLatch(1);
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                refreshCacheFromDatabase(context);
            } finally {
                latch.countDown();
            }
        });
        try {
            if (!latch.await(CACHE_LOAD_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                Log.w(TAG, "Timed out loading safety ground lock alarm preference; using default disabled=false");
                applyDefaultWhenCacheMissing();
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Interrupted while loading safety ground lock alarm preference; using default disabled=false");
            applyDefaultWhenCacheMissing();
        }
    }

    private static void applyDefaultWhenCacheMissing() {
        if (!cacheLoaded) {
            cachedEnabled = false;
            cacheLoaded = true;
        }
    }

    private static synchronized void refreshCacheFromDatabase(@NonNull Context context) {
        try {
            CommonSettings settings = loadOrCreate(context);
            cachedEnabled = isShowSafetyGroundLockAlarm(settings);
            cacheLoaded = true;
        } catch (RuntimeException exception) {
            Log.e(TAG, "Failed to load safety ground lock alarm preference", exception);
            applyDefaultWhenCacheMissing();
        }
    }

    private static CommonSettings loadOrCreate(Context context) {
        CommonSettingsDao dao = AppDatabase.getInstance(context).commonSettingsDao();
        CommonSettings settings = dao.selectOne();
        if (settings != null) {
            return settings;
        }
        settings = DefaultValueUtils.createDefaultCommonSettings();
        Locale locale = SystemSettingUtils.getLanguage();
        if (locale != null && "zh".equalsIgnoreCase(locale.getLanguage())) {
            settings.setLanguage(com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage.ZH_CN);
        }
        long id = dao.insert(settings);
        settings.setId((int) id);
        return settings;
    }

    @VisibleForTesting
    public static void setEnabledOverrideForTest(@Nullable Boolean enabled) {
        enabledOverrideForTest = enabled;
        if (enabled != null) {
            cachedEnabled = enabled;
            cacheLoaded = true;
        }
    }

    @VisibleForTesting
    public static void resetForTest() {
        enabledOverrideForTest = null;
        cacheLoaded = false;
        cachedEnabled = false;
    }

    static boolean isShowSafetyGroundLockAlarm(CommonSettings settings) {
        return settings != null && Boolean.TRUE.equals(settings.getShowSafetyGroundLockAlarm());
    }
}
