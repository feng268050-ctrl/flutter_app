package com.lasercyber.lws.ui.network.http.local;

import com.google.gson.JsonObject;

import org.junit.Assert;
import org.junit.Test;

public class CameraRecordSwitchBodyTest {

    @Test
    public void parseSwitchFromJson_acceptsOnOff() {
        JsonObject on = new JsonObject();
        on.addProperty("switch", "on");
        Assert.assertEquals("on", CameraRecordSwitchBody.parseSwitchFromJson(on));

        JsonObject off = new JsonObject();
        off.addProperty("switch", "off");
        Assert.assertEquals("off", CameraRecordSwitchBody.parseSwitchFromJson(off));
    }

    @Test
    public void parseSwitchFromJson_rejectsInvalid() {
        Assert.assertNull(CameraRecordSwitchBody.parseSwitchFromJson(null));
        Assert.assertNull(CameraRecordSwitchBody.parseSwitchFromJson(new JsonObject()));
        JsonObject bad = new JsonObject();
        bad.addProperty("switch", "maybe");
        Assert.assertNull(CameraRecordSwitchBody.parseSwitchFromJson(bad));
    }
}
