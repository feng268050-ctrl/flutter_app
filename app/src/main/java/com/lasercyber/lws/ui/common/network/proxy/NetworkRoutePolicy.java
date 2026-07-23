package com.lasercyber.lws.ui.common.network.proxy;

/**
 * Whether outbound HTTP traffic may use the configured device-wide HTTP proxy.
 */
public enum NetworkRoutePolicy {
    /** API, WebSocket, OTA, uploads — may route through HTTP proxy when enabled. */
    INTERNET_PROXY_AWARE,
    /** Camera LAN, localhost, MediaMTX — must stay direct. */
    DIRECT_LAN
}
