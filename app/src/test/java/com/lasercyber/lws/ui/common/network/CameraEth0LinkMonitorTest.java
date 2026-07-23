package com.lasercyber.lws.ui.common.network;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class CameraEth0LinkMonitorTest {

    @Test
    public void parseCarrierLine_acceptsZeroAndOne() {
        assertEquals(Integer.valueOf(0), CameraEth0LinkMonitor.parseCarrierLine("0"));
        assertEquals(Integer.valueOf(1), CameraEth0LinkMonitor.parseCarrierLine("1\n"));
        assertEquals(Integer.valueOf(1), CameraEth0LinkMonitor.parseCarrierLine(" 1 "));
    }

    @Test
    public void parseCarrierLine_rejectsUnknown() {
        assertNull(CameraEth0LinkMonitor.parseCarrierLine(null));
        assertNull(CameraEth0LinkMonitor.parseCarrierLine(""));
        assertNull(CameraEth0LinkMonitor.parseCarrierLine("2"));
    }

    @Test
    public void shouldReconfigure_onlyOnRisingEdge() {
        assertFalse(CameraEth0LinkMonitor.shouldReconfigureOnCarrierTransition(null, 1));
        assertFalse(CameraEth0LinkMonitor.shouldReconfigureOnCarrierTransition(1, 1));
        assertFalse(CameraEth0LinkMonitor.shouldReconfigureOnCarrierTransition(1, 0));
        assertFalse(CameraEth0LinkMonitor.shouldReconfigureOnCarrierTransition(0, 0));
        assertTrue(CameraEth0LinkMonitor.shouldReconfigureOnCarrierTransition(0, 1));
    }
}
