package com.lasercyber.lws.ui.bean.http;

import com.google.gson.JsonObject;

import org.junit.Assert;
import org.junit.Test;

public class CameraVideoOverlayEditorTest {

    @Test
    public void applyNameOverlay_enable1_setsPositionAndName() {
        JsonObject root = overlayRoot();
        JsonObject updated = CameraVideoOverlayEditor.applyNameOverlay(root, 1, 20, 30, "Laser-01");
        Assert.assertNotNull(updated);
        JsonObject nameOverlay = updated.getAsJsonObject("VideoOverlay").getAsJsonObject("NameOverlay");
        Assert.assertEquals(1, nameOverlay.get("enable").getAsInt());
        Assert.assertEquals(20, nameOverlay.get("x").getAsInt());
        Assert.assertEquals(80, nameOverlay.get("y").getAsInt());
        Assert.assertEquals("Laser-01", nameOverlay.get("name").getAsString());
    }

    @Test
    public void applyNameOverlay_enable0_hidesName() {
        JsonObject root = overlayRoot();
        JsonObject updated = CameraVideoOverlayEditor.applyNameOverlay(root, 0, 10, 10, "HGDevice");
        Assert.assertNotNull(updated);
        Assert.assertEquals(0,
                updated.getAsJsonObject("VideoOverlay")
                        .getAsJsonObject("NameOverlay")
                        .get("enable")
                        .getAsInt());
    }

    @Test
    public void parseOverlayConfig_rejectsErrCodeWrapper() {
        JsonObject error = new JsonObject();
        error.addProperty("errCode", 400);
        Assert.assertNull(CameraVideoOverlayEditor.parseOverlayConfig(error));
    }

    private static JsonObject overlayRoot() {
        JsonObject root = new JsonObject();
        JsonObject videoOverlay = new JsonObject();
        videoOverlay.add("NameOverlay", new JsonObject());
        root.add("VideoOverlay", videoOverlay);
        return root;
    }
}
