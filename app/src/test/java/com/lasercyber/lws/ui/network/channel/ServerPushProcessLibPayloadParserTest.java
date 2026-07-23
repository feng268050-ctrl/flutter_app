package com.lasercyber.lws.ui.network.channel;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;

import org.junit.Test;

public class ServerPushProcessLibPayloadParserTest {

    @Test
    public void parses_legacy_envelope_payload_with_data_wrapper() {
        JsonObject row = new JsonObject();
        row.addProperty("id", 1);
        JsonArray dataList = new JsonArray();
        dataList.add(row);
        JsonObject data = new JsonObject();
        data.addProperty("versionCode", 42);
        data.addProperty("versionStatus", 1);
        data.add("dataList", dataList);
        JsonObject root = new JsonObject();
        root.addProperty("msgType", 2);
        root.add("data", data);
        root.addProperty("msgId", "mid-1");

        ProcessLibraryPushPayload p = ServerPushProcessLibPayloadParser.parse(root);
        assertNotNull(p);
        assertNotNull(p.getLibrary());
        assertEquals(Integer.valueOf(42), p.getLibrary().getVersionCode());
        assertEquals("mid-1", p.getClientMessageId());
        assertEquals(1, p.getLibrary().getDataList().size());
    }

    @Test
    public void parses_bare_process_library_at_payload_root() {
        JsonObject row = new JsonObject();
        row.addProperty("id", 2);
        JsonArray dataList = new JsonArray();
        dataList.add(row);
        JsonObject root = new JsonObject();
        root.addProperty("versionCode", 7);
        root.add("dataList", dataList);

        ProcessLibraryPushPayload p = ServerPushProcessLibPayloadParser.parse(root);
        assertNotNull(p);
        assertNotNull(p.getLibrary());
        assertEquals(Integer.valueOf(7), p.getLibrary().getVersionCode());
        assertEquals(1, p.getLibrary().getDataList().size());
    }

    @Test
    public void returns_null_for_missing_data_list() {
        JsonObject root = new JsonObject();
        root.addProperty("versionCode", 1);
        assertNull(ServerPushProcessLibPayloadParser.parse(root));
    }

    @Test
    public void returns_null_for_null_payload() {
        assertNull(ServerPushProcessLibPayloadParser.parse(null));
    }
}
