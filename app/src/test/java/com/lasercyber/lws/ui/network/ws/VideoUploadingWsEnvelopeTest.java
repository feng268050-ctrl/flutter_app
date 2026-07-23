package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.JsonObject;

import org.junit.Test;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Mirrors {@link com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager#sendVideoUploading} payload shape.
 */
public class VideoUploadingWsEnvelopeTest {

    @Test
    public void videoUploadingEnvelope_hasExpectedPayloadKeys() {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("videoId", "vid-1");
        payload.put("uploadStatus", 2);
        payload.put("uploadProgress", 37);
        payload.put("videoUrl", "https://example/r2/obj");
        String json = DeviceWebSocketEnvelope.toJson("video.uploading", payload, "mid-1", 1L);
        JsonObject root = GsonUtils.fromJson(json, JsonObject.class);
        assertNotNull(root);
        assertEquals("video.uploading", root.get("type").getAsString());
        JsonObject p = root.getAsJsonObject("payload");
        assertEquals("vid-1", p.get("videoId").getAsString());
        assertEquals(2, p.get("uploadStatus").getAsInt());
        assertEquals(37, p.get("uploadProgress").getAsInt());
        assertEquals("https://example/r2/obj", p.get("videoUrl").getAsString());
    }
}
