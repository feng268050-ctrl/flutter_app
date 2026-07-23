package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import org.junit.Assert;
import org.junit.BeforeClass;
import org.junit.Test;

public class DeviceApiResultHttpTest {

    @BeforeClass
    public static void initGson() {
        GsonInitUtils.initGson();
    }

    @Test
    public void success_wrapsData() {
        String json = DeviceApiResultHttp.success(java.util.Map.of("list", java.util.List.of(), "total", 0));
        JsonObject o = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertTrue(o.get("success").getAsBoolean());
        Assert.assertEquals(200, o.get("code").getAsInt());
        Assert.assertTrue(o.get("data").isJsonObject());
    }

    @Test
    public void failure_setsSuccessFalse() {
        String json = DeviceApiResultHttp.failure(404, "video_not_found");
        JsonObject o = new JsonParser().parse(json).getAsJsonObject();
        Assert.assertFalse(o.get("success").getAsBoolean());
        Assert.assertEquals(404, o.get("code").getAsInt());
        Assert.assertEquals("video_not_found", o.get("message").getAsString());
    }
}
