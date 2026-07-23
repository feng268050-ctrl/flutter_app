package com.lasercyber.lws.ui.common.mdns;

import androidx.annotation.NonNull;

import java.util.Locale;

/**
 * Contract exposed to mobile app after service discovery.
 */
public final class DeviceConnectionEndpointContract {
    public static final String ERROR_ENDPOINT_UNREACHABLE = "ENDPOINT_UNREACHABLE";
    public static final String ERROR_HANDSHAKE_TIMEOUT = "HANDSHAKE_TIMEOUT";
    public static final String ERROR_PROTOCOL_MISMATCH = "PROTOCOL_MISMATCH";

    private DeviceConnectionEndpointContract() {
    }

    @NonNull
    public static Endpoint endpoint(String host, int port, String protocol) {
        return new Endpoint(host, port, normalizeProtocol(protocol));
    }

    @NonNull
    private static String normalizeProtocol(String protocol) {
        if (protocol == null) {
            return DeviceMdnsContract.CONNECT_PROTO_WS;
        }
        String normalized = protocol.trim().toLowerCase(Locale.US);
        if (DeviceMdnsContract.isSupportedProtocol(normalized)) {
            return normalized;
        }
        return DeviceMdnsContract.CONNECT_PROTO_WS;
    }

    public static final class Endpoint {
        private final String host;
        private final int port;
        private final String protocol;
        private final int handshakeTimeoutMs;
        private final int retryLimit;

        private Endpoint(String host, int port, String protocol) {
            this.host = host;
            this.port = port > 0 ? port : DeviceMdnsContract.DEFAULT_CONNECT_PORT;
            this.protocol = protocol;
            this.handshakeTimeoutMs = DeviceMdnsContract.HANDSHAKE_TIMEOUT_MS;
            this.retryLimit = DeviceMdnsContract.RETRY_LIMIT;
        }

        public String getHost() {
            return host;
        }

        public int getPort() {
            return port;
        }

        public String getProtocol() {
            return protocol;
        }

        public int getHandshakeTimeoutMs() {
            return handshakeTimeoutMs;
        }

        public int getRetryLimit() {
            return retryLimit;
        }
    }
}
