package com.lasercyber.lws.ui.common.camera;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

public class CameraRecordCoordinatorExclusiveStartTest {

    @After
    public void tearDown() {
        CameraRecordCoordinator.resetForTest();
    }

    @Test
    public void applyOn_whileRecordingActive_returns409WithConflictMessage() throws Exception {
        CameraRecordCoordinator.setRecordingActiveOverrideForTest(true);
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<CameraRecordCoordinator.Result> ref = new AtomicReference<>();
        CameraRecordCoordinator.getInstance().applySwitch("on", result -> {
            ref.set(result);
            latch.countDown();
        });
        Assert.assertTrue(latch.await(5, TimeUnit.SECONDS));
        CameraRecordCoordinator.Result result = ref.get();
        Assert.assertNotNull(result);
        Assert.assertFalse(result.success);
        Assert.assertEquals(409, result.httpCode);
        Assert.assertEquals("on", result.effectiveSwitch);
        Assert.assertEquals(
                CameraRecordCoordinator.recordingInProgressMessage(),
                result.errorMessage);
    }

    @Test
    public void applySwitchBlocking_whileRecordingActive_returns409() throws Exception {
        CameraRecordCoordinator.setRecordingActiveOverrideForTest(true);
        CameraRecordCoordinator.Result result =
                CameraRecordCoordinator.getInstance().applySwitchBlocking("on");
        Assert.assertFalse(result.success);
        Assert.assertEquals(409, result.httpCode);
        Assert.assertEquals(
                CameraRecordCoordinator.recordingInProgressMessage(),
                result.errorMessage);
    }

    @Test
    public void applySwitchBlocking_offWhileIdle_returnsOkOff() throws Exception {
        CameraRecordCoordinator.setRecordingActiveOverrideForTest(false);
        CameraRecordCoordinator.Result result =
                CameraRecordCoordinator.getInstance().applySwitchBlocking("off");
        Assert.assertTrue(result.success);
        Assert.assertEquals("off", result.effectiveSwitch);
    }
}
