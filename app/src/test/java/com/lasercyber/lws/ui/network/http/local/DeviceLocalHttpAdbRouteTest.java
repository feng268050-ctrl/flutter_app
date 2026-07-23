package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.Assert;
import org.junit.BeforeClass;
import org.junit.Test;

import java.net.HttpURLConnection;

/**
 * Route-level probe for {@code POST /v1/adb} (no Android {@link android.content.Context}).
 */
public class DeviceLocalHttpAdbRouteTest {

    @BeforeClass
    public static void initGson() {
        GsonInitUtils.initGson();
    }

    @Test
    public void adb_get_withoutAppContext_returnsServerNotReady() throws Exception {
        DeviceLocalHttpServer server = new DeviceLocalHttpServer(0);
        server.start();
        try {
            int port = server.getListeningPort();
            HttpURLConnection conn = (HttpURLConnection)
                    new java.net.URL("http://127.0.0.1:" + port + "/v1/adb").openConnection();
            conn.setRequestMethod("GET");
            // No app context → 500 before route dispatch; with context GET would be 404 not_found.
            Assert.assertEquals(500, conn.getResponseCode());
        } finally {
            server.stop();
        }
    }

    @Test
    public void adb_post_withoutAppContext_returnsServerNotReady() throws Exception {
        DeviceLocalHttpServer server = new DeviceLocalHttpServer(0);
        server.start();
        try {
            int port = server.getListeningPort();
            HttpURLConnection conn = (HttpURLConnection)
                    new java.net.URL("http://127.0.0.1:" + port + "/v1/adb").openConnection();
            conn.setRequestMethod("POST");
            Assert.assertEquals(500, conn.getResponseCode());
        } finally {
            server.stop();
        }
    }

    @Test
    public void success_nullData_shape() {
        String json = DeviceApiResultHttp.success(null);
        JsonObject o = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertTrue(o.get("success").getAsBoolean());
        Assert.assertEquals(200, o.get("code").getAsInt());
        Assert.assertTrue(o.get("data").isJsonNull());
    }

    @Test
    public void failure_adbEnableFailed_shape() {
        String json = DeviceApiResultHttp.failure(503, "adb_enable_failed");
        JsonObject o = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertFalse(o.get("success").getAsBoolean());
        Assert.assertEquals(503, o.get("code").getAsInt());
        Assert.assertEquals("adb_enable_failed", o.get("message").getAsString());
        Assert.assertTrue(o.get("data").isJsonNull());
    }

}
