package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Before;
import org.junit.Test;

public class OtaStageProgressDeduperTest {

    private OtaStageProgressDeduper deduper;

    @Before
    public void setUp() {
        deduper = new OtaStageProgressDeduper();
    }

    @Test
    public void notDelivered_untilMarked() {
        assertFalse(deduper.alreadyDelivered("download", 0));
    }

    @Test
    public void alreadyDelivered_sameStageAndProgress() {
        deduper.markDelivered("download", 0);
        assertTrue(deduper.alreadyDelivered("download", 0));
        assertFalse(deduper.alreadyDelivered("download", 10));
    }

    @Test
    public void differentStages_areIndependent() {
        deduper.markDelivered("download", 50);
        assertFalse(deduper.alreadyDelivered("preparing", 50));
    }

    @Test
    public void reset_clearsDelivery() {
        deduper.markDelivered("install-firmware", 100);
        deduper.reset();
        assertFalse(deduper.alreadyDelivered("install-firmware", 100));
    }
}
