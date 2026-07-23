package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingCorrectionStore;

import org.junit.Before;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class ZeroPointPendingCorrectionStoreTest {

    private ZeroPointPendingCorrectionStore store;

    @Before
    public void setUp() {
        store = ZeroPointPendingCorrectionStore.getInstance();
        store.clear();
    }

    @Test
    public void consumeLatest_returnsAndClearsWeldResult() {
        store.setWeldResult(7L, 3, -9.0, 1.5);

        assertTrue(store.hasFreshPending());
        ZeroPointPendingCorrectionStore.PendingCorrection result = store.consumeLatest();

        assertNotNull(result);
        assertEquals("weld_json", result.stageName);
        assertEquals(7L, result.eventId);
        assertEquals(3, result.validSamples);
        assertEquals(-9.0, result.meanOffsetX, 0.001);
        assertEquals(1.5, result.meanOffsetY, 0.001);
        assertNull(store.consumeLatest());
        assertFalse(store.hasFreshPending());
    }

    @Test
    public void setWeldResult_clearsWhenNoValidSamples() {
        store.setWeldResult(8L, 1, 6.0, 0.0);
        store.setWeldResult(9L, 0, 0.0, 0.0);

        assertNull(store.consumeLatest());
    }

    @Test
    public void consumeLatest_dropsExpiredResult() {
        store.setWeldResult(10L, 2, 12.0, 0.0);
        ZeroPointPendingCorrectionStore.PendingCorrection pending = store.peekForTest();

        assertNotNull(pending);
        assertNull(store.consumeLatest(pending.createdAtMs + 10 * 60 * 1000L + 1L));
        assertNull(store.consumeLatest());
    }
}
