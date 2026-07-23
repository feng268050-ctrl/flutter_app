package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import com.google.gson.JsonObject;

import org.junit.Test;

public class DeviceWsRowIdTest {

    @Test
    public void parse_stringId() {
        JsonObject payload = new JsonObject();
        payload.addProperty("id", "9007199254740991");
        assertEquals(Long.valueOf(9007199254740991L), DeviceWsRowId.parse(payload, "id"));
    }

    @Test
    public void parse_numericId() {
        JsonObject payload = new JsonObject();
        payload.addProperty("id", 42);
        assertEquals(Long.valueOf(42L), DeviceWsRowId.parse(payload, "id"));
    }

    @Test
    public void parse_invalidString() {
        JsonObject payload = new JsonObject();
        payload.addProperty("id", "abc");
        assertNull(DeviceWsRowId.parse(payload, "id"));
    }

    @Test
    public void toStringId() {
        assertEquals("123", DeviceWsRowId.toStringId(123L));
        assertNull(DeviceWsRowId.toStringId(null));
    }
}
