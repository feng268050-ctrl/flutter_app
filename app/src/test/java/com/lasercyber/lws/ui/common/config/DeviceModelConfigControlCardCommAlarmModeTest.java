package com.lasercyber.lws.ui.common.config;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class DeviceModelConfigControlCardCommAlarmModeTest {

    @Test
    public void missingPropertyDefaultsToSlideWindow() {
        assertEquals(ControlCardCommAlarmMode.SLIDE_WINDOW,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty(null));
        assertEquals(ControlCardCommAlarmMode.SLIDE_WINDOW,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty(""));
        assertEquals(ControlCardCommAlarmMode.SLIDE_WINDOW,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty("   "));
    }

    @Test
    public void slideWindowValue() {
        assertEquals(ControlCardCommAlarmMode.SLIDE_WINDOW,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty("slide_window"));
        assertEquals(ControlCardCommAlarmMode.SLIDE_WINDOW,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty("SLIDE_WINDOW"));
    }

    @Test
    public void immediateValue() {
        assertEquals(ControlCardCommAlarmMode.IMMEDIATE,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty("immediate"));
        assertEquals(ControlCardCommAlarmMode.IMMEDIATE,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty("IMMEDIATE"));
    }

    @Test
    public void invalidValueFallsBackToSlideWindow() {
        assertEquals(ControlCardCommAlarmMode.SLIDE_WINDOW,
                DeviceModelConfig.parseControlCardCommAlarmModeProperty("fast"));
    }
}
