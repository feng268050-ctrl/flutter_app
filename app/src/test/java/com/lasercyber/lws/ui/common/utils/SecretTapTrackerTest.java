package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class SecretTapTrackerTest {

    @Test
    public void registerTap_triggersAfterFiveTapsWithinWindow() {
        SecretTapTracker tracker = new SecretTapTracker();
        assertFalse(tracker.registerTap());
        assertFalse(tracker.registerTap());
        assertFalse(tracker.registerTap());
        assertFalse(tracker.registerTap());
        assertTrue(tracker.registerTap());
        assertFalse(tracker.registerTap());
    }

    @Test
    public void reset_clearsTapProgress() {
        SecretTapTracker tracker = new SecretTapTracker();
        tracker.registerTap();
        tracker.registerTap();
        tracker.reset();
        assertFalse(tracker.registerTap());
    }
}
