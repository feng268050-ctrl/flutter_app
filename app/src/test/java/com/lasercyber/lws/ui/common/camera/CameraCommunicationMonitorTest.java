package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertFalse;

import com.lasercyber.lws.ui.common.handler.CameraCommunicationAlarmController;

import org.junit.After;
import org.junit.Test;

public class CameraCommunicationMonitorTest {

    @After
    public void reset() {
        CameraCommunicationMonitor.stop();
        CameraPingHealthScheduler.getInstance().stop();
        CameraCommunicationAlarmController.getInstance().stop();
        CameraCommunicationMonitor.resetStartedForTest();
        CameraPingHealth.getInstance().resetForTest();
    }

    @Test
    public void startWhenHomeEntered_nullContext_doesNotStart() {
        CameraCommunicationMonitor.startWhenHomeEntered(null);
        assertFalse(CameraCommunicationMonitor.isStartedForTest());
        assertFalse(CameraPingHealthScheduler.isStartedForTest());
    }

    @Test
    public void stop_whenNotStarted_isSafe() {
        CameraCommunicationMonitor.stop();
        assertFalse(CameraCommunicationMonitor.isStartedForTest());
    }
}
