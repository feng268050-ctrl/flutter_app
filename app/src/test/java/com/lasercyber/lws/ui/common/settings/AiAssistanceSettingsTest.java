package com.lasercyber.lws.ui.common.settings;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

public class AiAssistanceSettingsTest {

    @After
    public void tearDown() {
        AiAssistanceSettings.resetForTest();
    }

    @Test
    public void defaultsEnabledWhenNoOverride() {
        assertTrue(AiAssistanceSettings.isLensContaminationDetectionEnabled(null));
        assertTrue(AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(null));
    }

    @Test
    public void overridesDisableProductionGates() {
        AiAssistanceSettings.setOverridesForTest(false, false);
        assertFalse(AiAssistanceSettings.isLensContaminationDetectionEnabled(null));
        assertFalse(AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(null));
    }

    @Test
    public void overridesCanBeIndependent() {
        AiAssistanceSettings.setOverridesForTest(true, false);
        assertTrue(AiAssistanceSettings.isLensContaminationDetectionEnabled(null));
        assertFalse(AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(null));
    }
}
