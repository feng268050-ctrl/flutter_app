package com.lasercyber.lws.ui.common.settings;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.common.handler.ZeroPointOffsetWarnAlarm;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.repository.AdvancedSettingsDao;

/**
 * Cached AI assistance toggles from {@code t_advanced_settings} for production laser-on coordinators.
 */
public final class AiAssistanceSettings {

    private static final String TAG = "AiAssistanceSettings";

    @Nullable
    private static Boolean lensEnabledOverrideForTest;
    @Nullable
    private static Boolean zeroPointEnabledOverrideForTest;
    private static volatile boolean cacheLoaded;
    private static volatile boolean cachedLensEnabled = true;
    private static volatile boolean cachedZeroPointEnabled = true;

    private AiAssistanceSettings() {
    }

    public static void warmCache(Context context) {
        ThreadPoolManager.getExecutor().execute(() -> refreshCacheFromDatabase(context.getApplicationContext()));
    }

    public static boolean isLensContaminationDetectionEnabled(@Nullable Context context) {
        if (lensEnabledOverrideForTest != null) {
            return lensEnabledOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedLensEnabled;
    }

    public static boolean isZeroPointOffsetDetectionEnabled(@Nullable Context context) {
        if (zeroPointEnabledOverrideForTest != null) {
            return zeroPointEnabledOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedZeroPointEnabled;
    }

    public static void setLensContaminationDetectionEnabled(Context context, boolean enabled) {
        applyLensEnabled(enabled);
        persistLensEnabled(context, enabled);
    }

    public static void setZeroPointOffsetDetectionEnabled(Context context, boolean enabled) {
        applyZeroPointEnabled(enabled);
        persistZeroPointEnabled(context, enabled);
    }

    public static void refreshCacheFromAdvancedSettings(@Nullable AdvancedSettings settings) {
        if (settings == null) {
            return;
        }
        cachedLensEnabled = isEnabled(settings.getLensContaminationDetectionEnabled());
        cachedZeroPointEnabled = isEnabled(settings.getZeroPointOffsetDetectionEnabled());
        cacheLoaded = true;
    }

    private static void applyLensEnabled(boolean enabled) {
        if (lensEnabledOverrideForTest != null) {
            lensEnabledOverrideForTest = enabled;
        }
        cachedLensEnabled = enabled;
        cacheLoaded = true;
        if (!enabled) {
            LensHeavyContaminationWarnAlarm.INSTANCE.onFaultCleared();
        }
        notifyAiDaemonAssistConfigChanged();
    }

    private static void applyZeroPointEnabled(boolean enabled) {
        if (zeroPointEnabledOverrideForTest != null) {
            zeroPointEnabledOverrideForTest = enabled;
        }
        cachedZeroPointEnabled = enabled;
        cacheLoaded = true;
        if (!enabled) {
            ZeroPointOffsetWarnAlarm.INSTANCE.onFaultCleared();
        }
        notifyAiDaemonAssistConfigChanged();
    }

    private static void notifyAiDaemonAssistConfigChanged() {
        try {
            com.lasercyber.lws.ai.daemon.AiDaemonSupervisor.getInstance().pushAiAssistConfigNow();
        } catch (Throwable ignored) {
            // Daemon supervisor may not be started yet.
        }
    }

    private static void persistLensEnabled(Context context, boolean enabled) {
        Context appContext = context.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            AdvancedSettings settings = loadOrCreate(appContext);
            settings.setLensContaminationDetectionEnabled(enabled);
            AppDatabase.getInstance(appContext).advancedSettingsDao().update(settings);
        });
    }

    private static void persistZeroPointEnabled(Context context, boolean enabled) {
        Context appContext = context.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            AdvancedSettings settings = loadOrCreate(appContext);
            settings.setZeroPointOffsetDetectionEnabled(enabled);
            AppDatabase.getInstance(appContext).advancedSettingsDao().update(settings);
        });
    }

    private static synchronized void refreshCacheFromDatabase(Context context) {
        try {
            AdvancedSettings settings = loadOrCreate(context);
            cachedLensEnabled = isEnabled(settings.getLensContaminationDetectionEnabled());
            cachedZeroPointEnabled = isEnabled(settings.getZeroPointOffsetDetectionEnabled());
            cacheLoaded = true;
        } catch (RuntimeException exception) {
            Log.e(TAG, "Failed to load AI assistance settings; using defaults enabled=true", exception);
            cachedLensEnabled = true;
            cachedZeroPointEnabled = true;
            cacheLoaded = true;
        }
    }

    private static AdvancedSettings loadOrCreate(Context context) {
        AdvancedSettingsDao dao = AppDatabase.getInstance(context).advancedSettingsDao();
        AdvancedSettings settings = dao.selectOne();
        if (settings != null) {
            return settings;
        }
        settings = DefaultValueUtils.createDefaultAdvancedSettings();
        long id = dao.insert(settings);
        settings.setId((int) id);
        return settings;
    }

    private static boolean isEnabled(@Nullable Boolean enabled) {
        return enabled == null || Boolean.TRUE.equals(enabled);
    }

    static void setOverridesForTest(@Nullable Boolean lensEnabled, @Nullable Boolean zeroPointEnabled) {
        lensEnabledOverrideForTest = lensEnabled;
        zeroPointEnabledOverrideForTest = zeroPointEnabled;
        if (lensEnabled != null) {
            cachedLensEnabled = lensEnabled;
        }
        if (zeroPointEnabled != null) {
            cachedZeroPointEnabled = zeroPointEnabled;
        }
        if (lensEnabled != null || zeroPointEnabled != null) {
            cacheLoaded = true;
        }
    }

    static void resetForTest() {
        lensEnabledOverrideForTest = null;
        zeroPointEnabledOverrideForTest = null;
        cacheLoaded = false;
        cachedLensEnabled = true;
        cachedZeroPointEnabled = true;
    }
}
