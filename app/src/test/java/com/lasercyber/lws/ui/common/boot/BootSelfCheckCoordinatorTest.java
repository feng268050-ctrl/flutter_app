package com.lasercyber.lws.ui.common.boot;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import com.lasercyber.lws.ui.common.camera.CameraCommunicationMonitor;

import org.junit.After;
import org.junit.Test;

public class BootSelfCheckCoordinatorTest {

    @After
    public void reset() {
        BootSelfCheckCoordinator.resetForTest();
        CameraCommunicationMonitor.stop();
    }

    @Test
    public void nullActivity_doesNotStart() {
        BootSelfCheckCoordinator.resetForTest();
        BootSelfCheckCoordinator.tryStartWhenHomeReady(null);
        assertFalse(BootSelfCheckCoordinator.isRunningForTest());
        assertFalse(BootSelfCheckCoordinator.isCompletedForTest());
        assertFalse(CameraCommunicationMonitor.isStartedForTest());
    }

    @Test
    public void itemOrder_matchesAlarmInformationSequence() {
        BootSelfCheckItem[] items = BootSelfCheckItem.values();
        assertEquals(9, items.length);
        assertEquals(BootSelfCheckItem.CONTROLLER_COMM, items[0]);
        assertEquals(BootSelfCheckItem.PUMP_COMM, items[1]);
        assertEquals(BootSelfCheckItem.CAMERA_COMM, items[items.length - 1]);
    }
}
