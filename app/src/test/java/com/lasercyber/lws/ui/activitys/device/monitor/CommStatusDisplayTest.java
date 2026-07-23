package com.lasercyber.lws.ui.activitys.device.monitor;

import org.junit.Assert;
import org.junit.Test;

public class CommStatusDisplayTest {

    @Test
    public void emulator_notReady_isNeutral() {
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolve(true, false, false));
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolve(true, false, true));
    }

    @Test
    public void emulator_readyWithAlarm_isNeutral() {
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolve(true, true, true));
    }

    @Test
    public void emulator_readyHealthy_isHealthy() {
        Assert.assertEquals(CommStatusDisplay.HEALTHY,
                CommStatusDisplay.resolve(true, true, false));
    }

    @Test
    public void device_notReady_isFault() {
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolve(false, false, false));
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolve(false, false, true));
    }

    @Test
    public void device_readyWithAlarm_isFault() {
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolve(false, true, true));
    }

    @Test
    public void device_readyHealthy_isHealthy() {
        Assert.assertEquals(CommStatusDisplay.HEALTHY,
                CommStatusDisplay.resolve(false, true, false));
    }

    /** Camera comm tile uses the same adapter as gun/feeder (cameraCommFault = comm alarm). */
    @Test
    public void cameraComm_deviceReadyFault_isFault() {
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolve(false, true, true));
    }

    @Test
    public void cameraComm_emulatorReadyFault_withoutHost_isNeutral() {
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolveCameraComm(true, true, true, false));
    }

    @Test
    public void cameraComm_emulatorConfiguredHost_fault_isFault() {
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolveCameraComm(true, false, true, true));
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolveCameraComm(true, true, true, true));
    }

    @Test
    public void cameraComm_emulatorConfiguredHost_healthy_isHealthy() {
        Assert.assertEquals(CommStatusDisplay.HEALTHY,
                CommStatusDisplay.resolveCameraComm(true, false, false, true));
        Assert.assertEquals(CommStatusDisplay.HEALTHY,
                CommStatusDisplay.resolveCameraComm(true, true, false, true));
    }

    @Test
    public void metric_notReady_isNeutral() {
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolveMetric(false, true, false));
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolveMetric(true, false, false));
    }

    @Test
    public void metric_readyNoValue_isNeutral() {
        Assert.assertEquals(CommStatusDisplay.NEUTRAL,
                CommStatusDisplay.resolveMetric(true, false, true));
    }

    @Test
    public void metric_readyWithValueAndFault_isFault() {
        Assert.assertEquals(CommStatusDisplay.FAULT,
                CommStatusDisplay.resolveMetric(true, true, true));
    }

    @Test
    public void metric_readyWithValueHealthy_isHealthy() {
        Assert.assertEquals(CommStatusDisplay.HEALTHY,
                CommStatusDisplay.resolveMetric(true, true, false));
    }
}
