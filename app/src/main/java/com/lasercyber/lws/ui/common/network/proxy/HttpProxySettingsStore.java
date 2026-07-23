package com.lasercyber.lws.ui.common.network.proxy;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import androidx.annotation.NonNull;

/**
 * Persists {@link HttpProxySettings} in private {@link SharedPreferences}.
 */
public final class HttpProxySettingsStore {

    private static final String PREFS = "http_proxy_settings";
    private static final String KEY_ENABLED = "enabled";
    private static final String KEY_HOST = "host";
    private static final String KEY_PORT = "port";
    private static final String KEY_AUTH_TYPE = "auth_type";
    private static final String KEY_USERNAME = "username";
    private static final String KEY_PASSWORD = "password";

    private final SharedPreferences prefs;

    public HttpProxySettingsStore(@NonNull Context context) {
        this.prefs = context.getApplicationContext()
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    @NonNull
    public HttpProxySettings load() {
        HttpProxySettings settings = new HttpProxySettings();
        settings.enabled = prefs.getBoolean(KEY_ENABLED, false);
        settings.host = nullToEmpty(prefs.getString(KEY_HOST, ""));
        settings.port = prefs.getInt(KEY_PORT, 0);
        settings.authType = parseAuthType(prefs.getString(KEY_AUTH_TYPE, ProxyAuthType.NONE.name()));
        settings.username = nullToEmpty(prefs.getString(KEY_USERNAME, ""));
        settings.password = nullToEmpty(prefs.getString(KEY_PASSWORD, ""));
        return settings;
    }

    public void save(@NonNull HttpProxySettings settings) {
        prefs.edit()
                .putBoolean(KEY_ENABLED, settings.enabled)
                .putString(KEY_HOST, settings.host == null ? "" : settings.host.trim())
                .putInt(KEY_PORT, settings.port)
                .putString(KEY_AUTH_TYPE, settings.authType.name())
                .putString(KEY_USERNAME, settings.username == null ? "" : settings.username)
                .putString(KEY_PASSWORD, settings.password == null ? "" : settings.password)
                .apply();
    }

    @NonNull
    private static ProxyAuthType parseAuthType(@NonNull String raw) {
        try {
            return ProxyAuthType.valueOf(raw);
        } catch (IllegalArgumentException ignored) {
            return ProxyAuthType.NONE;
        }
    }

    @NonNull
    private static String nullToEmpty(@NonNull String value) {
        return TextUtils.isEmpty(value) ? "" : value;
    }
}
