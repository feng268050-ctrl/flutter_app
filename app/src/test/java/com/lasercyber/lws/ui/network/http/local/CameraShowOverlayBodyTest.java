package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;

import org.junit.Assert;
import org.junit.Test;

public class CameraShowOverlayBodyTest {

    @Test
    public void parseFromJson_enable1_defaultsPosition() {
        JsonObject json = new JsonObject();
        json.addProperty("enable", 1);
        CameraShowOverlayBody.Request request = CameraShowOverlayBody.parseFromJson(json);
        Assert.assertNotNull(request);
        Assert.assertEquals(Integer.valueOf(1), request.enable);
        Assert.assertEquals(Integer.valueOf(10), request.positionX);
        Assert.assertEquals(Integer.valueOf(10), request.positionY);
    }

    @Test
    public void parseFromJson_enable1_rejectsYAbove238() {
        JsonObject json = new JsonObject();
        json.addProperty("enable", 1);
        json.addProperty("positiony", 239);
        Assert.assertNull(CameraShowOverlayBody.parseFromJson(json));
    }

    @Test
    public void parseFromJson_enable0_allowsYUpTo288() {
        JsonObject json = new JsonObject();
        json.addProperty("enable", 0);
        json.addProperty("positiony", 288);
        Assert.assertNotNull(CameraShowOverlayBody.parseFromJson(json));
    }

    @Test
    public void resolveMachineModel_delegatesToDeviceModelConfig() {
        Assert.assertFalse(CameraShowOverlayBody.resolveMachineModel().isEmpty());
    }
}
