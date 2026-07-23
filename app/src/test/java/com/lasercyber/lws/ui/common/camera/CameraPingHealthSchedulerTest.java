package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertFalse;

import org.junit.After;
import org.junit.Test;

public class CameraPingHealthSchedulerTest {

    @After
    public void reset() {
        CameraPingHealth.getInstance().resetForTest();
        CameraPingHealthScheduler.getInstance().stop();
    }

    @Test
    public void stop_clearsStartedFlag() {
        CameraPingHealthScheduler.getInstance().stop();
        assertFalse(CameraPingHealthScheduler.isStartedForTest());
    }
}
