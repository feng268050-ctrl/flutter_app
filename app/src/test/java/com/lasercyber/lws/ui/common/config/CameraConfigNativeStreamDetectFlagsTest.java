package com.lasercyber.lws.ui.common.config;

import org.junit.Assert;
import org.junit.Test;

public final class CameraConfigNativeStreamDetectFlagsTest {

    @Test
    public void nativeStreamDetect_orOfWeldAndAiVision() {
        boolean weld = CameraConfig.isNativeWeldStreamDetectEnabled();
        boolean aiVision = CameraConfig.isNativeAiVisionStreamDetectEnabled();
        Assert.assertEquals(weld || aiVision, CameraConfig.isNativeStreamDetectPipelineEnabled());
    }

    @Test
    public void weldNative_alwaysEnabledAfterPhase4() {
        Assert.assertTrue(CameraConfig.isNativeWeldStreamDetectEnabled());
    }

    @Test
    public void aiVisionOverlay_falseWhenDualLinkOff() {
        if (!CameraConfig.isNativeAiVisionStreamDetectEnabled()) {
            Assert.assertFalse(CameraConfig.isAiVisionLiveDetectOverlayEnabled());
        }
    }

    @Test
    public void fourFourFallback_aiVisionDetectOffByDefault() {
        Assert.assertFalse(CameraConfig.isNativeAiVisionStreamDetectEnabled());
        Assert.assertFalse(CameraConfig.isAiVisionLiveDetectOverlayEnabled());
    }

    @Test
    public void resolutionProfileLogging_followsFieldTestFlag() {
        Assert.assertEquals(
                CameraConfig.isAiVisionDualLinkFieldTestLoggingEnabled(),
                CameraConfig.isAiVisionResolutionProfileLoggingEnabled());
    }
}
