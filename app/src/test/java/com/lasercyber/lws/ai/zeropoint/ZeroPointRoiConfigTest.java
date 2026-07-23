package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlaySnapshot;
import com.lasercyber.lws.ai.zeropoint.ZeroPointRoiConfig;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class ZeroPointRoiConfigTest {

    @Test
    public void scaleReferenceToFrame_scalesFromSourceSize() {
        ZeroPointRoiConfig config = new ZeroPointRoiConfig(1920, 1080, 882.0, 536.0);
        ZeroPointRoiConfig.ScaledReference scaled = config.scaleReferenceToFrame(960, 540);
        assertEquals(441.0, scaled.x, 0.01);
        assertEquals(268.0, scaled.y, 0.01);
    }

    @Test
    public void overlaySnapshot_computesDetectedFromReferencePlusOffset() {
        ZeroPointOverlaySnapshot snapshot = new ZeroPointOverlaySnapshot(
                1920, 1080, 882.0, 536.0, 12.5, -8.0);
        assertEquals(894.5, snapshot.detectedX, 0.01);
        assertEquals(528.0, snapshot.detectedY, 0.01);
        assertEquals("Δ(12.5, -8.0)", snapshot.labelText());
    }
}
