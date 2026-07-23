package com.lasercyber.lws.ui.common.boot;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.common.handler.DeviceDialogHandler;

import org.junit.After;
import org.junit.Test;

public class BootSelfCheckGateTest {

    @After
    public void reset() {
        BootSelfCheckGate.resetForTest();
        BootSelfCheckEvaluator.resetForTest();
    }

    @Test
    public void defaultsInactive() {
        assertFalse(BootSelfCheckGate.isActive());
        assertFalse(DeviceDialogHandler.isAsyncWarnSuppressed());
    }

    @Test
    public void activeSuppressesAsyncWarnDialogs() {
        BootSelfCheckGate.setActive(true);
        assertTrue(BootSelfCheckGate.isActive());
        assertTrue(DeviceDialogHandler.isAsyncWarnSuppressed());
        BootSelfCheckGate.setActive(false);
        assertFalse(DeviceDialogHandler.isAsyncWarnSuppressed());
    }
}
