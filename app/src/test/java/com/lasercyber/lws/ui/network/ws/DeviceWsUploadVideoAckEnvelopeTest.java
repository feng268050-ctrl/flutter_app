package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.JsonObject;

import org.junit.Test;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * {@link DeviceWebSocketConnectionManager#sendUploadVideoAck(String, boolean, String)} envelope shape.
 */
public class DeviceWsUploadVideoAckEnvelopeTest {

    private static String buildUploadVideoAckJson(String requestId, boolean success, String message) {
        String rid = requestId != null ? requestId : "";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("success", success);
        data.put("message", message != null ? message : "");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", rid);
        payload.put("data", data);
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        return DeviceWebSocketEnvelope.toJson("command.upload_video_ack", payload, id, System.currentTimeMillis());
    }

    @Test
    public void uploadVideoAckEnvelope_hasNestedDataAndRequestId() {
        String json = buildUploadVideoAckJson("req-inbound-1", true, "");
        JsonObject root = GsonUtils.fromJson(json, JsonObject.class);
        assertNotNull(root);
        assertEquals("command.upload_video_ack", root.get("type").getAsString());
        assertNotEquals("req-inbound-1", root.get("id").getAsString());
        JsonObject p = root.getAsJsonObject("payload");
        assertEquals("req-inbound-1", p.get("request_id").getAsString());
        JsonObject data = p.getAsJsonObject("data");
        assertTrue(data.get("success").getAsBoolean());
        assertEquals("", data.get("message").getAsString());
    }

    @Test
    public void uploadVideoAckEnvelope_failureCarriesMessage() {
        String json = buildUploadVideoAckJson("req-2", false, "video_not_found");
        JsonObject root = GsonUtils.fromJson(json, JsonObject.class);
        assertNotNull(root);
        JsonObject data = root.getAsJsonObject("payload").getAsJsonObject("data");
        assertFalse(data.get("success").getAsBoolean());
        assertEquals("video_not_found", data.get("message").getAsString());
    }

    @Test
    public void uploadVideoAckEnvelope_requestIdMatchesInboundCorrelation() {
        String inboundId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
        String json = buildUploadVideoAckJson(inboundId, true, "ok");
        JsonObject root = GsonUtils.fromJson(json, JsonObject.class);
        assertEquals(inboundId, root.getAsJsonObject("payload").get("request_id").getAsString());
    }
}
