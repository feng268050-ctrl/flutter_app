package com.lasercyber.lws.ui.common.network.proxy;

/**
 * Logical HTTP client role; drives timeout and protocol defaults in {@link NetworkHttpClientProvider}.
 */
public enum ClientPurpose {
    API,
    WEBSOCKET,
    PROBE,
    OTA_MANIFEST,
    OTA_DOWNLOAD,
    UPLOAD
}
