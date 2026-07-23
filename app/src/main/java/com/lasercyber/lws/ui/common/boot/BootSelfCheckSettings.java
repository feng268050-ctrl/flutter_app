package com.lasercyber.lws.ui.common.boot;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;

import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Reads and writes startup self-check preference from {@code t_common_settings.showBootSelfCheck}
 * so it is included in {@code command.stat_response} / {@code device.online} {@code commonSettings}.
 */
public final class BootSelfCheckSettings {

    private static final String TAG = LogTAGConstant.BootSelfCheck;
    private static final String LEGACY_PREF = "lws_boot_self_check";
    private static final String LEGACY_KEY_DISABLED = "disabled";

    private static final long CACHE_LOAD_TIMEOUT_MS = 2_000L;

    @Nullable
    private static Boolean enabledOverrideForTest;
    private static volatile boolean cacheLoaded;
    private static volatile boolean cachedEnabled = true;

    private BootSelfCheckSettings() {
    }

    public static void warmCache(Context context) {
        ThreadPoolManager.getExecutor().execute(() -> refreshCacheFromDatabase(context.getApplicationContext()));
    }

    public static boolean isEnabled(Context context) {
        if (enabledOverrideForTest != null) {
            return enabledOverrideForTest;
        }
        if (!cacheLoaded) {
            ensureCacheLoaded(context != null ? context.getApplicationContext() : null);
        }
        return cachedEnabled;
    }

    public static boolean isEnabledBlocking(@Nullable Context context) {
        if (enabledOverrideForTest != null) {
            return enabledOverrideForTest;
        }
        if (cacheLoaded) {
            return cachedEnabled;
        }
        ensureCacheLoaded(context != null ? context.getApplicationContext() : null);
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
            settings.setShowBootSelfCheck(enabled);
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
                Log.w(TAG, "Timed out loading boot self-check preference; using default enabled=true");
                applyDefaultWhenCacheMissing();
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            Log.w(TAG, "Interrupted while loading boot self-check preference; using default enabled=true");
            applyDefaultWhenCacheMissing();
        }
    }

    private static void applyDefaultWhenCacheMissing() {
        if (!cacheLoaded) {
            cachedEnabled = true;
            cacheLoaded = true;
        }
    }
    private static synchronized void refreshCacheFromDatabase(@NonNull Context context) {
        try {
            migrateLegacyPreferenceIfNeeded(context);
            CommonSettings settings = loadOrCreate(context);
            cachedEnabled = isShowBootSelfCheck(settings);
            cacheLoaded = true;
        } catch (RuntimeException exception) {
            Log.e(TAG, "Failed to load boot self-check preference", exception);
            applyDefaultWhenCacheMissing();
        }
    }

    private static void migrateLegacyPreferenceIfNeeded(Context context) {
        SharedPreferences legacy = context.getApplicationContext()
                .getSharedPreferences(LEGACY_PREF, Context.MODE_PRIVATE);
        if (!legacy.contains(LEGACY_KEY_DISABLED)) {
            return;
        }
        boolean disabled = legacy.getBoolean(LEGACY_KEY_DISABLED, false);
        CommonSettings settings = loadOrCreate(context);
        settings.setShowBootSelfCheck(!disabled);
        AppDatabase.getInstance(context).commonSettingsDao().update(settings);
        legacy.edit().clear().apply();
        cachedEnabled = !disabled;
        cacheLoaded = true;
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

    static void setEnabledOverrideForTest(@Nullable Boolean enabled) {
        enabledOverrideForTest = enabled;
        if (enabled != null) {
            cachedEnabled = enabled;
            cacheLoaded = true;
        }
    }

    static void resetForTest() {
        enabledOverrideForTest = null;
        cacheLoaded = false;
        cachedEnabled = true;
    }

    static boolean isShowBootSelfCheck(CommonSettings settings) {
        return settings != null
                && (settings.getShowBootSelfCheck() == null || Boolean.TRUE.equals(settings.getShowBootSelfCheck()));
    }
}
