package com.lasercyber.lws.ui.common.upgrade;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

/**
 * Persists whether the home screen should automatically check for OTA updates once per process.
 */
public final class AutoCheckOtaUpdateSettings {

    private static final String PREF = "lws_auto_check_ota_update";
    private static final String KEY_ENABLED = "enabled";

    @Nullable
    private static volatile Boolean enabledOverrideForTest;

    @Nullable
    public static volatile SharedPreferences testPrefsOverride;

    private AutoCheckOtaUpdateSettings() {
    }

    public static boolean isEnabled(@Nullable Context context) {
        if (enabledOverrideForTest != null) {
            return enabledOverrideForTest;
        }
        SharedPreferences prefs = prefsOrNull(context);
        return prefs != null && prefs.getBoolean(KEY_ENABLED, false);
    }

    public static void setEnabled(@Nullable Context context, boolean enabled) {
        SharedPreferences prefs = prefsOrNull(context);
        if (prefs == null) {
            return;
        }
        prefs.edit().putBoolean(KEY_ENABLED, enabled).apply();
    }

    @VisibleForTesting
    public static void resetForTest() {
        enabledOverrideForTest = null;
        testPrefsOverride = null;
    }

    @VisibleForTesting
    public static void setEnabledOverrideForTest(@Nullable Boolean enabled) {
        enabledOverrideForTest = enabled;
    }

    @Nullable
    private static SharedPreferences prefsOrNull(@Nullable Context context) {
        if (testPrefsOverride != null) {
            return testPrefsOverride;
        }
        if (context == null) {
            return null;
        }
        return context.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }
}
