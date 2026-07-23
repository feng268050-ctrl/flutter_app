package com.lasercyber.lws.ui.common.mdns;

import androidx.annotation.NonNull;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Device-side mDNS/DNS-SD contract exposed to mobile discovery clients.
 */
public final class DeviceMdnsContract {
    public static final String SERVICE_TYPE = "_lws-device._tcp.";
    /**
     * Type string for JmDNS / Bonjour registration (includes {@code .local.} zone).
     * Clients still browse {@link #SERVICE_TYPE} / {@code _lws-device._tcp} — same service class.
     */
    public static final String JMDNS_SERVICE_TYPE = "_lws-device._tcp.local.";
    public static final String CONNECT_PROTO_WS = "ws";
    public static final String CONNECT_PROTO_HTTP = "http";
    public static final String API_VERSION = "1";

    public static final String TXT_SN = "sn";
    public static final String TXT_MODEL = "model";
    /** Installed HMI APK {@code versionName}; matches Settings → Device Information → System Version. */
    public static final String TXT_SYSTEM_VERSION = "system_version";
    public static final String TXT_API_VER = "api_ver";
    public static final String TXT_CONNECT_PROTO = "connect_proto";

    public static final int DEFAULT_CONNECT_PORT = 9527;
    public static final int HANDSHAKE_TIMEOUT_MS = 5000;
    public static final int RETRY_LIMIT = 3;

    private static final Set<String> REQUIRED_TXT_KEYS = new HashSet<>(Arrays.asList(
            TXT_SN,
            TXT_MODEL,
            TXT_SYSTEM_VERSION,
            TXT_API_VER,
            TXT_CONNECT_PROTO
    ));

    private DeviceMdnsContract() {
    }

    public static boolean isSupportedProtocol(String protocol) {
        if (protocol == null) {
            return false;
        }
        String normalized = protocol.trim().toLowerCase(Locale.US);
        return CONNECT_PROTO_WS.equals(normalized) || CONNECT_PROTO_HTTP.equals(normalized);
    }

    @NonNull
    public static Set<String> requiredTxtKeys() {
        return new HashSet<>(REQUIRED_TXT_KEYS);
    }
}
