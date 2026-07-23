package com.lasercyber.lws.ui.network.ws;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.dto.DeviceRemoteSnapshot;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginProber;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import okhttp3.HttpUrl;

public class DeviceWebSocketConnectionTest {

    @Before
    public void setUp() {
        GsonInitUtils.initGson();
    }

    @Before
    @After
    public void resetApiOrigin() {
        DeviceApiOriginProber.resetForTest();
        DeviceApiOriginConfig.resetOriginSelectionForTest();
    }

    @Test
    public void https_api_origins_include_scheme() {
        assertTrue(DeviceApiOriginConfig.HTTPS_ORIGIN_PROD.startsWith("https://"));
        assertTrue(DeviceApiOriginConfig.HTTPS_ORIGIN_TEST.startsWith("https://"));
        assertFalse(DeviceApiOriginConfig.HTTPS_ORIGIN_PROD.endsWith("/"));
    }

    @Test
    public void should_build_ws_url_with_encoded_sn() {
        String url = DeviceWebSocketConfig.buildDeviceWsUrl("api-test.lasercyber.workers.dev", "SN 01");
        assertEquals("wss://api-test.lasercyber.workers.dev/ws/device?sn=SN+01", url);
    }

    @Test
    public void build_device_ws_url_uses_pin_when_present() {
        DeviceApiOriginConfig.setPinnedBaseForTest(HttpUrl.get("http://47.86.53.176:8080/test"));
        String url = DeviceWebSocketConfig.buildDeviceWsUrl("SN1");
        assertEquals("ws://47.86.53.176:8080/test/ws/device?sn=SN1", url);
    }

    @Test
    public void should_reject_invalid_sn() {
        try {
            DeviceWebSocketConfig.buildDeviceWsUrl("api-test.lasercyber.workers.dev", "unknown-sn");
            fail("expected IllegalArgumentException");
        } catch (IllegalArgumentException expected) {
            assertTrue(expected.getMessage().contains("invalid device sn"));
        }
    }

    @Test
    public void should_compute_exponential_backoff_with_cap() {
        assertEquals(1000L, DeviceWebSocketConnectionManager.computeBackoffMs(1));
        assertEquals(2000L, DeviceWebSocketConnectionManager.computeBackoffMs(2));
        assertEquals(4000L, DeviceWebSocketConnectionManager.computeBackoffMs(3));
        assertEquals(30000L, DeviceWebSocketConnectionManager.computeBackoffMs(10));
    }

    @Test
    public void should_classify_auth_and_replace_close_codes() {
        assertEquals("auth_invalid_sn", DeviceWebSocketConnectionManager.classifyCloseCode(401));
        assertEquals("replaced_by_new_connection", DeviceWebSocketConnectionManager.classifyCloseCode(4409));
        assertEquals("disconnect_generic", DeviceWebSocketConnectionManager.classifyCloseCode(1006));
    }

    @Test
    public void retryConnectAfterAuthError_clearsAuthLatch() {
        DeviceWebSocketConnectionManager mgr = DeviceWebSocketConnectionManager.getInstance();
        mgr.setAuthErrorStateForTest();
        assertTrue(mgr.isAuthErrorReconnectBlocked());
        mgr.retryConnectAfterAuthError("test_reconnect");
        assertFalse(mgr.isAuthErrorReconnectBlocked());
        assertNull(mgr.getLastErrorCode());
        assertNotEquals(DeviceWsConnectionState.OFFLINE_AUTH_ERROR, mgr.getState());
    }

    @Test
    public void envelope_should_round_trip_and_require_all_top_level_fields() {
        String id = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("ack", java.util.Map.of(), id, 1_700_000_000_000L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals(1, p.v);
        assertEquals("ack", p.type);
        assertEquals(id, p.id);
        assertEquals(1_700_000_000_000L, p.ts);
        assertTrue(p.payload.entrySet().isEmpty());

        assertNull(DeviceWebSocketEnvelope.parse("{\"v\":1,\"type\":\"x\",\"ts\":1,\"payload\":{}}"));
        assertNull(DeviceWebSocketEnvelope.parse("{}"));
        assertNull(DeviceWebSocketEnvelope.parse("{\"v\":1,\"type\":\"x\",\"id\":\"i\",\"ts\":1,\"payload\":[]}"));
        assertNull(DeviceWebSocketEnvelope.parse("{\"v\":1,\"type\":\"x\",\"id\":\"i\",\"ts\":1,\"payload\":\"bad\"}"));
        assertNull(DeviceWebSocketEnvelope.parse("{\"v\":2,\"type\":\"ack\",\"id\":\"i\",\"ts\":1,\"payload\":{}}"));
    }

    @Test
    public void new_unique_message_ids_should_differ() {
        String a = DeviceWebSocketEnvelope.newUniqueMessageId();
        String b = DeviceWebSocketEnvelope.newUniqueMessageId();
        assertNotEquals(a, b);
    }

    @Test
    public void connected_payload_validation() {
        JsonObject ok = new JsonObject();
        ok.addProperty("sn", "SN1");
        ok.addProperty("connection_id", "cid");
        assertTrue(DeviceWebSocketEnvelope.isValidConnectedPayload(ok));

        JsonObject bad = new JsonObject();
        bad.addProperty("sn", "");
        bad.addProperty("connection_id", "x");
        assertFalse(DeviceWebSocketEnvelope.isValidConnectedPayload(bad));
        assertFalse(DeviceWebSocketEnvelope.isValidConnectedPayload(new JsonObject()));
    }

    @Test
    public void process_lib_ack_envelope_shape() {
        String inboundRequestId = "server-lib-req-1";
        Map<String, Object> pl = new LinkedHashMap<>();
        pl.put("request_id", inboundRequestId);
        pl.put("code", 200);
        pl.put("message", "success");
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.send_process_lib_ack", pl, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.send_process_lib_ack", p.type);
        assertEquals(outId, p.id);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertEquals(200, p.payload.get("code").getAsInt());
        assertEquals("success", DeviceWebSocketEnvelope.payloadString(p.payload, "message"));
    }

    @Test
    public void process_param_ack_envelope_shape() {
        String inboundRequestId = "server-req-abc";
        Map<String, Object> pl = new LinkedHashMap<>();
        pl.put("request_id", inboundRequestId);
        pl.put("code", 200);
        pl.put("message", "success");
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.send_process_param_ack", pl, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.send_process_param_ack", p.type);
        assertEquals(outId, p.id);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertEquals(200, p.payload.get("code").getAsInt());
        assertEquals("success", DeviceWebSocketEnvelope.payloadString(p.payload, "message"));
    }

    @Test
    public void device_online_envelope_has_stat_wrapper_without_request_id() {
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("deviceStatus", null);
        Map<String, Object> processParameters = new LinkedHashMap<>();
        processParameters.put("laserPower", 45);
        snapshot.put("processParameters", processParameters);
        snapshot.put("wifiSsid", "lab");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("stat", snapshot);
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("device.online", payload, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals(1, p.v);
        assertEquals("device.online", p.type);
        assertEquals(outId, p.id);
        assertFalse(p.payload.has("request_id"));
        assertFalse(p.payload.has("data"));
        assertFalse(p.payload.has("wifiSsid"));
        assertTrue(p.payload.has("stat"));
        assertFalse(p.payload.getAsJsonObject("stat").has("request_id"));
        assertFalse(p.payload.getAsJsonObject("stat").has("data"));
        assertTrue(p.payload.getAsJsonObject("stat").has("wifiSsid"));
        assertTrue(p.payload.getAsJsonObject("stat").has("processParameters"));
        assertEquals("lab", DeviceWebSocketEnvelope.payloadString(p.payload.getAsJsonObject("stat"), "wifiSsid"));
        assertEquals(45, p.payload.getAsJsonObject("stat")
                .getAsJsonObject("processParameters").get("laserPower").getAsInt());
    }

    @Test
    public void device_online_envelope_serializes_null_snapshot_fields() {
        Map<String, Object> stat = new LinkedHashMap<>();
        stat.put("processParameters", null);
        stat.put("deviceStatus", null);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("stat", stat);
        String json = DeviceWebSocketEnvelope.toJson(
                "device.online", payload, DeviceWebSocketEnvelope.newUniqueMessageId(), 1L);
        assertTrue(json.contains("\"processParameters\":null"));
        assertTrue(json.contains("\"deviceStatus\":null"));
    }

    @Test
    public void remote_snapshot_gson_serializes_null_process_parameter_fields() {
        DeviceRemoteSnapshot snapshot = new DeviceRemoteSnapshot();
        DeviceInfo deviceInfo = new DeviceInfo();
        deviceInfo.setFocusScaleRef(-3);
        snapshot.setDeviceInfo(deviceInfo);
        snapshot.setProcessParameters(new ProcessParametersData());
        String json = GsonInitUtils.getGson().toJson(snapshot);
        assertTrue(json.contains("\"focusScaleRef\":-3"));
        assertTrue(json.contains("\"processParameters\":{"));
        assertTrue(json.contains("\"laserPower\":null"));
        assertTrue(json.contains("\"name\":null"));
    }

    @Test
    public void device_online_stat_matches_stat_response_data() {
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("deviceStatus", null);
        Map<String, Object> processParameters = new LinkedHashMap<>();
        processParameters.put("laserPower", 45);
        snapshot.put("processParameters", processParameters);
        snapshot.put("wifiSsid", "lab");
        Map<String, Object> deviceInfo = new LinkedHashMap<>();
        deviceInfo.put("focusScaleRef", -3);
        snapshot.put("deviceInfo", deviceInfo);
        Map<String, Object> onlinePayload = new LinkedHashMap<>();
        onlinePayload.put("stat", snapshot);
        Map<String, Object> statResponsePayload = new LinkedHashMap<>();
        statResponsePayload.put("request_id", "server-stat-req-1");
        statResponsePayload.put("data", snapshot);
        String onlineJson = DeviceWebSocketEnvelope.toJson(
                "device.online", onlinePayload, DeviceWebSocketEnvelope.newUniqueMessageId(), 1L);
        String statJson = DeviceWebSocketEnvelope.toJson(
                "command.stat_response", statResponsePayload, DeviceWebSocketEnvelope.newUniqueMessageId(), 1L);
        DeviceWebSocketEnvelope.Parsed online = DeviceWebSocketEnvelope.parse(onlineJson);
        DeviceWebSocketEnvelope.Parsed stat = DeviceWebSocketEnvelope.parse(statJson);
        assertNotNull(online);
        assertNotNull(stat);
        assertEquals(online.payload.get("stat"), stat.payload.get("data"));
        assertEquals(-3, online.payload.getAsJsonObject("stat")
                .getAsJsonObject("deviceInfo").get("focusScaleRef").getAsInt());
        assertEquals(-3, stat.payload.getAsJsonObject("data")
                .getAsJsonObject("deviceInfo").get("focusScaleRef").getAsInt());
    }

    @Test
    public void stat_response_envelope_has_request_id_and_data_without_device() {
        String inboundRequestId = "server-stat-req-1";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("deviceStatus", null);
        Map<String, Object> processParameters = new LinkedHashMap<>();
        processParameters.put("wireFeedSpeed", 12.5d);
        data.put("processParameters", processParameters);
        Map<String, Object> deviceInfo = new LinkedHashMap<>();
        deviceInfo.put("focusScaleRef", 0);
        data.put("deviceInfo", deviceInfo);
        Map<String, Object> pl = new LinkedHashMap<>();
        pl.put("request_id", inboundRequestId);
        pl.put("data", data);
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.stat_response", pl, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.stat_response", p.type);
        assertEquals(outId, p.id);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertTrue(p.payload.has("data"));
        assertTrue(p.payload.get("data").isJsonObject());
        assertFalse(p.payload.getAsJsonObject("data").has("device"));
        assertTrue(p.payload.getAsJsonObject("data").has("processParameters"));
        assertEquals(0, p.payload.getAsJsonObject("data")
                .getAsJsonObject("deviceInfo")
                .get("focusScaleRef").getAsInt());
        assertEquals(12.5d, p.payload.getAsJsonObject("data")
                .getAsJsonObject("processParameters")
                .get("wireFeedSpeed").getAsDouble(), 0.0001d);
    }

    @Test
    public void clear_alerts_ack_envelope_shape_matches_upload_video_ack() {
        String inboundRequestId = "server-clear-1";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("success", true);
        data.put("message", "");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", inboundRequestId);
        payload.put("data", data);
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.clear_alerts_ack", payload, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.clear_alerts_ack", p.type);
        assertEquals(outId, p.id);
        assertNotEquals(inboundRequestId, p.id);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertTrue(p.payload.get("data").isJsonObject());
        assertTrue(p.payload.getAsJsonObject("data").get("success").getAsBoolean());
        assertEquals("", p.payload.getAsJsonObject("data").get("message").getAsString());
    }

    @Test
    public void clear_alerts_command_envelope_parses_with_empty_payload() {
        String json = "{"
                + "\"v\":1,"
                + "\"type\":\"command.clear_alerts\","
                + "\"id\":\"srv-clear-1\","
                + "\"ts\":1710000000001,"
                + "\"payload\":{}"
                + "}";
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.clear_alerts", p.type);
        assertEquals("srv-clear-1", p.id);
        assertTrue(p.payload.entrySet().isEmpty());
    }

    @Test
    public void stat_request_envelope_parses_like_other_commands() {
        String json = "{"
                + "\"v\":1,"
                + "\"type\":\"command.stat_request\","
                + "\"id\":\"srv-stat-1\","
                + "\"ts\":1710000000001,"
                + "\"payload\":{}"
                + "}";
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.stat_request", p.type);
        assertEquals("srv-stat-1", p.id);
        assertTrue(p.payload.entrySet().isEmpty());
    }

    @Test
    public void check_update_ack_envelope_shape() {
        String inboundRequestId = "server-check-1";
        Map<String, Object> manifest = new LinkedHashMap<>();
        manifest.put("version", "1.2.3");
        manifest.put("filename", "1.2.3.zip");
        manifest.put("published_at", "2026-01-01T00:00:00Z");
        manifest.put("sha512", "abc");
        manifest.put("url", "https://example.com/1.2.3.zip");
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("ok", true);
        data.put("has_update", true);
        data.put("manifest", manifest);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", inboundRequestId);
        payload.put("data", data);
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.check_update_ack", payload, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.check_update_ack", p.type);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertTrue(p.payload.get("data").isJsonObject());
        assertTrue(p.payload.getAsJsonObject("data").get("has_update").getAsBoolean());
    }

    @Test
    public void process_parameters_mutation_ack_envelope_shape() {
        String inboundRequestId = "server-pp-1";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("success", true);
        data.put("message", "");
        data.put("id", "42");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", inboundRequestId);
        payload.put("data", data);
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.process_parameters_create_ack", payload, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.process_parameters_create_ack", p.type);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertTrue(p.payload.get("data").isJsonObject());
        assertEquals("42", p.payload.getAsJsonObject("data").get("id").getAsString());
        assertTrue(p.payload.getAsJsonObject("data").get("success").getAsBoolean());
    }

    @Test
    public void process_library_response_data_array_envelope_shape() {
        String inboundRequestId = "server-lib-2";
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("id", "1");
        item.put("name", "a");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", inboundRequestId);
        payload.put("data", java.util.List.of(item));
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.process_library_response", payload, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.process_library_response", p.type);
        assertTrue(p.payload.get("data").isJsonArray());
        assertEquals("1",
                p.payload.getAsJsonArray("data").get(0).getAsJsonObject().get("id").getAsString());
    }

    @Test
    public void process_parameters_response_envelope_shape() {
        String inboundRequestId = "server-get-1";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("id", "99");
        data.put("laserPower", 30);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", inboundRequestId);
        payload.put("data", data);
        String json = DeviceWebSocketEnvelope.toJson(
                "command.process_parameters_response",
                payload,
                DeviceWebSocketEnvelope.newUniqueMessageId(),
                1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertEquals("99", p.payload.getAsJsonObject("data").get("id").getAsString());
    }

    @Test
    public void update_system_ack_envelope_shape_includes_started() {
        String inboundRequestId = "server-update-1";
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("ok", true);
        data.put("started", true);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("request_id", inboundRequestId);
        payload.put("data", data);
        String outId = DeviceWebSocketEnvelope.newUniqueMessageId();
        String json = DeviceWebSocketEnvelope.toJson("command.update_system_ack", payload, outId, 1L);
        DeviceWebSocketEnvelope.Parsed p = DeviceWebSocketEnvelope.parse(json);
        assertNotNull(p);
        assertEquals("command.update_system_ack", p.type);
        assertEquals(inboundRequestId, DeviceWebSocketEnvelope.payloadString(p.payload, "request_id"));
        assertTrue(p.payload.getAsJsonObject("data").get("started").getAsBoolean());
    }
}
