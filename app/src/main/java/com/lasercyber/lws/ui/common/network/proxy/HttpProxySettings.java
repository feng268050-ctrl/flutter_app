package com.lasercyber.lws.ui.common.network.proxy;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Device-wide HTTP proxy configuration (v1: HTTP proxy + optional Basic auth).
 */
public final class HttpProxySettings {

    public boolean enabled;
    @NonNull
    public String host = "";
    public int port;
    @NonNull
    public ProxyAuthType authType = ProxyAuthType.NONE;
    @NonNull
    public String username = "";
    @NonNull
    public String password = "";

    public HttpProxySettings() {
    }

    public HttpProxySettings(
            boolean enabled,
            @NonNull String host,
            int port,
            @NonNull ProxyAuthType authType,
            @NonNull String username,
            @NonNull String password) {
        this.enabled = enabled;
        this.host = host;
        this.port = port;
        this.authType = authType;
        this.username = username;
        this.password = password;
    }

    @NonNull
    public static HttpProxySettings disabled() {
        return new HttpProxySettings();
    }

    @NonNull
    public HttpProxySettings copy() {
        return new HttpProxySettings(enabled, host, port, authType, username, password);
    }

    public boolean hasValidEndpoint() {
        return !host.trim().isEmpty() && port > 0 && port <= 65535;
    }

    public boolean shouldApplyProxy() {
        return enabled && hasValidEndpoint();
    }

    @Override
    public boolean equals(@Nullable Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof HttpProxySettings other)) {
            return false;
        }
        return enabled == other.enabled
                && port == other.port
                && host.equals(other.host)
                && authType == other.authType
                && username.equals(other.username)
                && password.equals(other.password);
    }
}
