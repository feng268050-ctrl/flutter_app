package com.lasercyber.lws.ui.common.config;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class DeviceModelConfigCameraTypeTest {

    @Test
    public void missingPropertyDefaultsToBlueLight() {
        assertEquals(CameraType.BLUE_LIGHT, DeviceModelConfig.parseCameraTypeProperty(null));
        assertEquals(CameraType.BLUE_LIGHT, DeviceModelConfig.parseCameraTypeProperty(""));
        assertEquals(CameraType.BLUE_LIGHT, DeviceModelConfig.parseCameraTypeProperty("   "));
    }

    @Test
    public void blueLightValue() {
        assertEquals(CameraType.BLUE_LIGHT, DeviceModelConfig.parseCameraTypeProperty("1"));
    }

    @Test
    public void redLightValue() {
        assertEquals(CameraType.RED_LIGHT, DeviceModelConfig.parseCameraTypeProperty("2"));
    }

    @Test
    public void invalidValueFallsBackToBlueLight() {
        assertEquals(CameraType.BLUE_LIGHT, DeviceModelConfig.parseCameraTypeProperty("99"));
        assertEquals(CameraType.BLUE_LIGHT, DeviceModelConfig.parseCameraTypeProperty("blue"));
    }
}
