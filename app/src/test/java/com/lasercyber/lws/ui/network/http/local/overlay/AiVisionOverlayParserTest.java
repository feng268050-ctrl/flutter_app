package com.lasercyber.lws.ui.network.http.local.overlay;

import com.lasercyber.lws.ui.common.view.DetectionOverlayView;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class AiVisionOverlayParserTest {

    @Test
    public void resolveDisplayMessage_plainText() {
        Assert.assertEquals("waiting", AiVisionOverlayParser.resolveDisplayMessage("waiting"));
    }

    @Test
    public void buildFallbackBoxes_stainHeavy() {
        List<DetectionOverlayView.Box> boxes =
                AiVisionOverlayParser.buildFallbackBoxes("stain_heavy", "{}");
        Assert.assertEquals(1, boxes.size());
        Assert.assertEquals(1f, boxes.get(0).x2, 0.001f);
    }

    @Test
    public void snapshot_updatesDisplayMessage() {
        CameraAiOverlayState state = CameraAiOverlayState.getInstance();
        state.updateFromCheckResult("plain status text", "clean");
        CameraAiOverlayState.Snapshot snap = state.getSnapshot();
        Assert.assertEquals("plain status text", snap.displayMessage);
        Assert.assertEquals(1, snap.boxes.size());
    }
}
