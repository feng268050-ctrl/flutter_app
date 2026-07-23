package com.lasercyber.lws.ui.common.config;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.BuildConfig;

import java.util.Locale;

/**
 * Runtime app tier (Dev / Test / Prod): defaults from Gradle {@code APP_ENV}, {@code DEBUG},
 * {@code RELEASE_CHANNEL}. Retrofit uses the same Worker API origin as {@link DeviceApiOriginConfig#getRetrofitBaseUrl()}.
 * User tier override persisted after the hidden Settings gesture.
 * <p>
 * Effective release channel for Worker routing mirrors {@linkplain #getEffectiveTier() Prod vs non-Prod}
 * (runtime counterpart to {@link BuildConfig#RELEASE_CHANNEL}).
 */
public final class AppRuntimeEnvironment {

    private static final String PREF = "lws_app_runtime_env";
    private static final String KEY_TIER_OVERRIDE = "tier_override";

    @Nullable
    private static volatile Context appContext;
    /** In-process only: WiFi init gate passed (connected, or first-home prompt handled). */
    private static volatile boolean wifiInitializationGatePassed;

    private AppRuntimeEnvironment() {
    }

    public enum Tier {
        DEV,
        TEST,
        PROD;

        @Nullable
        static Tier fromPersisted(@Nullable String s) {
            if (s == null || s.isEmpty()) {
                return null;
            }
            try {
                return Tier.valueOf(s.trim().toUpperCase(Locale.US));
            } catch (IllegalArgumentException e) {
                return null;
            }
        }
    }

    public static void init(Context context) {
        appContext = context.getApplicationContext();
    }

    @Nullable
    private static SharedPreferences prefsOrNull() {
        Context ctx = appContext;
        if (ctx == null) {
            return null;
        }
        return ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    /**
     * Default tier when the user has not chosen an override (and prefs are unavailable, e.g. unit tests).
     */
    public static Tier defaultTierFromBuild() {
        String env = BuildConfig.APP_ENV != null ? BuildConfig.APP_ENV.trim() : "";
        if ("prod".equalsIgnoreCase(env)) {
            return Tier.PROD;
        }
        if ("test".equalsIgnoreCase(env)) {
            return Tier.TEST;
        }
        if ("dev".equalsIgnoreCase(env)) {
            return Tier.DEV;
        }
        if (BuildConfig.DEBUG) {
            return Tier.DEV;
        }
        if (BuildConfig.RELEASE_CHANNEL) {
            return Tier.PROD;
        }
        return Tier.TEST;
    }

    public static Tier getEffectiveTier() {
        SharedPreferences p = prefsOrNull();
        if (p != null) {
            Tier t = Tier.fromPersisted(p.getString(KEY_TIER_OVERRIDE, null));
            if (t != null) {
                return t;
            }
        }
        return defaultTierFromBuild();
    }

    /**
     * Dev entry is shown only when {@link BuildConfig#APP_ENV} is empty or {@code dev} (case-insensitive).
     */
    public static boolean isDevOptionVisible() {
        String env = BuildConfig.APP_ENV != null ? BuildConfig.APP_ENV.trim() : "";
        return env.isEmpty() || "dev".equalsIgnoreCase(env);
    }

    /**
     * Runtime counterpart to {@link BuildConfig#RELEASE_CHANNEL}: {@code true} when the effective tier is Prod.
     */
    public static boolean effectiveReleaseChannel() {
        return getEffectiveTier() == Tier.PROD;
    }

    public static void persistTierOverride(Context context, Tier tier) {
        context.getApplicationContext()
                .getSharedPreferences(PREF, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TIER_OVERRIDE, tier.name().toLowerCase(Locale.US))
                .apply();
        appContext = context.getApplicationContext();
    }

    /**
     * Whether the WiFi initialization step is done for this app process
     * (already on WiFi at first home entry, user dismissed the prompt, or WiFi connected later).
     */
    public static boolean isWifiInitializationCompleted() {
        return wifiInitializationGatePassed;
    }

    public static void markWifiInitializationCompleted(@Nullable Context context) {
        wifiInitializationGatePassed = true;
        if (context != null) {
            appContext = context.getApplicationContext();
        }
    }
}
