package com.lasercyber.lws.ui.network.ws;

/**
 * User-visible copy for {@code command.disconnect} (spec-driven wording).
 */
public final class ForcedWsDisconnectMessage {
    static final String TITLE = "Disconnected from Server";
    private static final String BODY_PREFIX =
            "This device has been forced to disconnect from the server, reason: ";

    private ForcedWsDisconnectMessage() {
    }

    public static String body(String reasonFromPayload) {
        return BODY_PREFIX + (reasonFromPayload != null ? reasonFromPayload : "");
    }
}
