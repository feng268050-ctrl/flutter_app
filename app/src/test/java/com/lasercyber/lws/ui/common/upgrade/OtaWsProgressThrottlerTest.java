package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Before;
import org.junit.Test;

public class OtaWsProgressThrottlerTest {

    private long now;
    private OtaWsProgressThrottler throttler;

    @Before
    public void setUp() {
        now = 0L;
        throttler = new OtaWsProgressThrottler(() -> now);
    }

    @Test
    public void shouldPost_firstReadingAfterReset() {
        assertTrue(throttler.shouldPost(0));
    }

    @Test
    public void shouldPost_whenProgressAdvancesTenPercentFromLastPosted() {
        throttler.markPosted(0);
        assertFalse(throttler.shouldPost(5));
        assertTrue(throttler.shouldPost(10));
    }

    @Test
    public void shouldPost_sixteenAfterTimeBasedPostAtSix() {
        throttler.markPosted(0);
        now = OtaWsProgressThrottler.MIN_INTERVAL_MS;
        assertTrue(throttler.shouldPost(6));
        throttler.markPosted(6);
        assertFalse(throttler.shouldPost(15));
        assertTrue(throttler.shouldPost(16));
    }

    @Test
    public void shouldPost_afterMinIntervalWhenProgressIncreased() {
        throttler.markPosted(0);
        now = 50L;
        assertFalse(throttler.shouldPost(3));
        now = OtaWsProgressThrottler.MIN_INTERVAL_MS;
        assertTrue(throttler.shouldPost(3));
    }

    @Test
    public void shouldNotRepostSamePercentAfterInterval() {
        throttler.markPosted(42);
        now = 1000L;
        assertFalse(throttler.shouldPost(42));
    }

    @Test
    public void shouldPost_hundredImmediatelyWhenNotYetPosted() {
        throttler.markPosted(95);
        assertTrue(throttler.shouldPost(100));
    }

    @Test
    public void shouldNotRepost_hundredWhenAlreadyPosted() {
        throttler.markPosted(100);
        assertFalse(throttler.shouldPost(100));
    }

    @Test
    public void shouldNotPost_regressingPercent() {
        throttler.markPosted(50);
        assertFalse(throttler.shouldPost(40));
    }

    @Test
    public void reset_allowsFirstPostAgain() {
        throttler.markPosted(80);
        throttler.reset();
        assertTrue(throttler.shouldPost(1));
    }
}
