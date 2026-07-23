package com.lasercyber.lws.ui.common.config;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class DeviceModelConfigFocusScaleRefTest {

    @Test
    public void missingPropertyDefaultsToZero() {
        assertEquals(0, DeviceModelConfig.parseFocusScaleRefProperty(null));
        assertEquals(0, DeviceModelConfig.parseFocusScaleRefProperty(""));
        assertEquals(0, DeviceModelConfig.parseFocusScaleRefProperty("   "));
    }

    @Test
    public void positiveValue() {
        assertEquals(5, DeviceModelConfig.parseFocusScaleRefProperty("5"));
        assertEquals(0, DeviceModelConfig.parseFocusScaleRefProperty("0"));
    }

    @Test
    public void negativeValue() {
        assertEquals(-3, DeviceModelConfig.parseFocusScaleRefProperty("-3"));
    }

    @Test
    public void invalidValueFallsBackToZero() {
        assertEquals(0, DeviceModelConfig.parseFocusScaleRefProperty("abc"));
        assertEquals(0, DeviceModelConfig.parseFocusScaleRefProperty("5.5"));
    }
}
