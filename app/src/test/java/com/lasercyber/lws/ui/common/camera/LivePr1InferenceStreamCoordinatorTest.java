package com.lasercyber.lws.ui.common.camera;

import org.junit.Assert;
import org.junit.Test;

public class LivePr1InferenceStreamCoordinatorTest {

    @Test
    public void shouldRunInferenceStream_requiresAttachedLiveInferAndSession() {
        Assert.assertTrue(LivePr1InferenceStreamCoordinator.shouldRunInferenceStream(
                true, true, true));
        Assert.assertFalse(LivePr1InferenceStreamCoordinator.shouldRunInferenceStream(
                false, true, true));
        Assert.assertFalse(LivePr1InferenceStreamCoordinator.shouldRunInferenceStream(
                true, false, true));
        Assert.assertFalse(LivePr1InferenceStreamCoordinator.shouldRunInferenceStream(
                true, true, false));
    }

    @Test
    public void shouldRunInferenceStream_graceKeepsStreamEligibleWhenLaserOff() {
        Assert.assertTrue(LivePr1InferenceStreamCoordinator.shouldRunInferenceStream(
                true, true, true));
    }
}
