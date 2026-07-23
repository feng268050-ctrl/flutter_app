package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class ForcedWsDisconnectMessageTest {

    @Test
    public void body_appends_reason_or_empty() {
        assertEquals(
                "This device has been forced to disconnect from the server, reason: ",
                ForcedWsDisconnectMessage.body(""));
        assertEquals(
                "This device has been forced to disconnect from the server, reason: policy",
                ForcedWsDisconnectMessage.body("policy"));
        assertEquals(
                "This device has been forced to disconnect from the server, reason: ",
                ForcedWsDisconnectMessage.body(null));
    }

    @Test
    public void title_is_spec_literal() {
        assertEquals("Disconnected from Server", ForcedWsDisconnectMessage.TITLE);
    }
}
