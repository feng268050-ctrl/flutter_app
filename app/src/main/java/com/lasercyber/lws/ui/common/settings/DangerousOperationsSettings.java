package com.lasercyber.lws.ui.common.settings;

import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.repository.AdvancedSettingsDao;

/**
 * Cached dangerous-operations toggles from {@code t_advanced_settings} for laser-enable guards.
 */
public final class DangerousOperationsSettings {

    private static final String TAG = "DangerousOpsSettings";

    @Nullable
    private static Boolean allowCameraOverrideForTest;
    @Nullable
    private static Boolean allowGasOverrideForTest;
    @Nullable
    private static Boolean allowLensOverrideForTest;
    @Nullable
    private static Boolean allowFeederOverrideForTest;
    @Nullable
    private static Boolean keepLaserOnWhileAlarmedOverrideForTest;
    private static volatile boolean cacheLoaded;
    private static volatile boolean cachedAllowCamera;
    private static volatile boolean cachedAllowGas;
    private static volatile boolean cachedAllowLens;
    private static volatile boolean cachedAllowFeeder;
    private static volatile boolean cachedKeepLaserOnWhileAlarmed;

    private DangerousOperationsSettings() {
    }

    public static void warmCache(Context context) {
        ThreadPoolManager.getExecutor().execute(() -> refreshCacheFromDatabase(context.getApplicationContext()));
    }

    public static boolean isAllowWorkAfterCameraAlarm(@Nullable Context context) {
        if (allowCameraOverrideForTest != null) {
            return allowCameraOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedAllowCamera;
    }

    public static boolean isAllowWorkAfterGasAlarm(@Nullable Context context) {
        if (allowGasOverrideForTest != null) {
            return allowGasOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedAllowGas;
    }

    public static boolean isAllowWorkAfterLensContamination(@Nullable Context context) {
        if (allowLensOverrideForTest != null) {
            return allowLensOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedAllowLens;
    }

    public static boolean isAllowWorkAfterFeederAlarm(@Nullable Context context) {
        if (allowFeederOverrideForTest != null) {
            return allowFeederOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedAllowFeeder;
    }

    public static boolean isKeepLaserOnWhileAlarmed(@Nullable Context context) {
        if (keepLaserOnWhileAlarmedOverrideForTest != null) {
            return keepLaserOnWhileAlarmedOverrideForTest;
        }
        if (!cacheLoaded && context != null) {
            warmCache(context.getApplicationContext());
        }
        return cachedKeepLaserOnWhileAlarmed;
    }

    public static void setAllowWorkAfterCameraAlarm(Context context, boolean enabled) {
        applyAllowCamera(enabled);
        persistAllowCamera(context, enabled);
        if (!enabled) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(context);
        }
    }

    public static void setAllowWorkAfterGasAlarm(Context context, boolean enabled) {
        applyAllowGas(enabled);
        persistAllowGas(context, enabled);
        if (!enabled) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(context);
        }
    }

    public static void setAllowWorkAfterLensContamination(Context context, boolean enabled) {
        applyAllowLens(enabled);
        persistAllowLens(context, enabled);
        if (!enabled) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(context);
        }
    }

    public static void setAllowWorkAfterFeederAlarm(Context context, boolean enabled) {
        applyAllowFeeder(enabled);
        persistAllowFeeder(context, enabled);
        if (!enabled) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(context);
        }
    }

    public static void setKeepLaserOnWhileAlarmed(Context context, boolean enabled) {
        applyKeepLaserOnWhileAlarmed(enabled);
        persistKeepLaserOnWhileAlarmed(context, enabled);
        if (!enabled) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(context);
        }
    }

    public static void refreshCacheFromAdvancedSettings(@Nullable AdvancedSettings settings) {
        if (settings == null) {
            return;
        }
        cachedAllowCamera = isEnabled(settings.getAllowWorkAfterCameraAlarm());
        cachedAllowGas = isEnabled(settings.getAllowWorkAfterGasAlarm());
        cachedAllowLens = isEnabled(settings.getAllowWorkAfterLensContamination());
        cachedAllowFeeder = isEnabled(settings.getAllowWorkAfterFeederAlarm());
        cachedKeepLaserOnWhileAlarmed = isEnabled(settings.getKeepLaserOnWhileAlarmed());
        cacheLoaded = true;
    }

    private static void applyAllowCamera(boolean enabled) {
        if (allowCameraOverrideForTest != null) {
            allowCameraOverrideForTest = enabled;
        }
        cachedAllowCamera = enabled;
        cacheLoaded = true;
    }

    private static void applyAllowGas(boolean enabled) {
        if (allowGasOverrideForTest != null) {
            allowGasOverrideForTest = enabled;
        }
        cachedAllowGas = enabled;
        cacheLoaded = true;
    }

    private static void applyAllowLens(boolean enabled) {
        if (allowLensOverrideForTest != null) {
            allowLensOverrideForTest = enabled;
        }
        cachedAllowLens = enabled;
        cacheLoaded = true;
    }

    private static void applyAllowFeeder(boolean enabled) {
        if (allowFeederOverrideForTest != null) {
            allowFeederOverrideForTest = enabled;
        }
        cachedAllowFeeder = enabled;
        cacheLoaded = true;
    }

    private static void applyKeepLaserOnWhileAlarmed(boolean enabled) {
        if (keepLaserOnWhileAlarmedOverrideForTest != null) {
            keepLaserOnWhileAlarmedOverrideForTest = enabled;
        }
        cachedKeepLaserOnWhileAlarmed = enabled;
        cacheLoaded = true;
    }

    private static void persistAllowCamera(Context context, boolean enabled) {
        persistField(context, settings -> settings.setAllowWorkAfterCameraAlarm(enabled));
    }

    private static void persistAllowGas(Context context, boolean enabled) {
        persistField(context, settings -> settings.setAllowWorkAfterGasAlarm(enabled));
    }

    private static void persistAllowLens(Context context, boolean enabled) {
        persistField(context, settings -> settings.setAllowWorkAfterLensContamination(enabled));
    }

    private static void persistAllowFeeder(Context context, boolean enabled) {
        persistField(context, settings -> settings.setAllowWorkAfterFeederAlarm(enabled));
    }

    private static void persistKeepLaserOnWhileAlarmed(Context context, boolean enabled) {
        persistField(context, settings -> settings.setKeepLaserOnWhileAlarmed(enabled));
    }

    private static void persistField(Context context, java.util.function.Consumer<AdvancedSettings> mutator) {
        Context appContext = context.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            AdvancedSettings settings = loadOrCreate(appContext);
            mutator.accept(settings);
            AppDatabase.getInstance(appContext).advancedSettingsDao().update(settings);
        });
    }

    private static synchronized void refreshCacheFromDatabase(Context context) {
        try {
            AdvancedSettings settings = loadOrCreate(context);
            cachedAllowCamera = isEnabled(settings.getAllowWorkAfterCameraAlarm());
            cachedAllowGas = isEnabled(settings.getAllowWorkAfterGasAlarm());
            cachedAllowLens = isEnabled(settings.getAllowWorkAfterLensContamination());
            cachedAllowFeeder = isEnabled(settings.getAllowWorkAfterFeederAlarm());
            cachedKeepLaserOnWhileAlarmed = isEnabled(settings.getKeepLaserOnWhileAlarmed());
            cacheLoaded = true;
        } catch (RuntimeException exception) {
            Log.e(TAG, "Failed to load dangerous operations settings; using defaults enabled=false", exception);
            cachedAllowCamera = false;
            cachedAllowGas = false;
            cachedAllowLens = false;
            cachedAllowFeeder = false;
            cachedKeepLaserOnWhileAlarmed = false;
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
        return Boolean.TRUE.equals(enabled);
    }

    @VisibleForTesting
    public static void setOverridesForTest(
            @Nullable Boolean allowCamera,
            @Nullable Boolean allowGas,
            @Nullable Boolean allowLens) {
        setOverridesForTest(allowCamera, allowGas, allowLens, null, null);
    }

    @VisibleForTesting
    public static void setOverridesForTest(
            @Nullable Boolean allowCamera,
            @Nullable Boolean allowGas,
            @Nullable Boolean allowLens,
            @Nullable Boolean keepLaserOnWhileAlarmed) {
        setOverridesForTest(allowCamera, allowGas, allowLens, null, keepLaserOnWhileAlarmed);
    }

    @VisibleForTesting
    public static void setOverridesForTest(
            @Nullable Boolean allowCamera,
            @Nullable Boolean allowGas,
            @Nullable Boolean allowLens,
            @Nullable Boolean allowFeeder,
            @Nullable Boolean keepLaserOnWhileAlarmed) {
        allowCameraOverrideForTest = allowCamera;
        allowGasOverrideForTest = allowGas;
        allowLensOverrideForTest = allowLens;
        allowFeederOverrideForTest = allowFeeder;
        keepLaserOnWhileAlarmedOverrideForTest = keepLaserOnWhileAlarmed;
        if (allowCamera != null) {
            cachedAllowCamera = allowCamera;
        }
        if (allowGas != null) {
            cachedAllowGas = allowGas;
        }
        if (allowLens != null) {
            cachedAllowLens = allowLens;
        }
        if (allowFeeder != null) {
            cachedAllowFeeder = allowFeeder;
        }
        if (keepLaserOnWhileAlarmed != null) {
            cachedKeepLaserOnWhileAlarmed = keepLaserOnWhileAlarmed;
        }
        if (allowCamera != null || allowGas != null || allowLens != null || allowFeeder != null
                || keepLaserOnWhileAlarmed != null) {
            cacheLoaded = true;
        }
    }

    @VisibleForTesting
    public static void resetForTest() {
        allowCameraOverrideForTest = null;
        allowGasOverrideForTest = null;
        allowLensOverrideForTest = null;
        allowFeederOverrideForTest = null;
        keepLaserOnWhileAlarmedOverrideForTest = null;
        cacheLoaded = false;
        cachedAllowCamera = false;
        cachedAllowGas = false;
        cachedAllowLens = false;
        cachedAllowFeeder = false;
        cachedKeepLaserOnWhileAlarmed = false;
    }
}
