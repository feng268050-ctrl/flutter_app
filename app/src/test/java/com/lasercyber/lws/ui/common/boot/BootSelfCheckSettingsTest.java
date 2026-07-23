package com.lasercyber.lws.ui.common.boot;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

public class BootSelfCheckSettingsTest {

    @After
    public void reset() {
        BootSelfCheckSettings.resetForTest();
    }

    @Test
    public void enabledByDefault() {
        BootSelfCheckSettings.setEnabledOverrideForTest(true);
        assertTrue(BootSelfCheckSettings.isEnabled(null));
    }

    @Test
    public void disabledWhenOptedOut() {
        BootSelfCheckSettings.setEnabledOverrideForTest(false);
        assertFalse(BootSelfCheckSettings.isEnabled(null));
    }
}
