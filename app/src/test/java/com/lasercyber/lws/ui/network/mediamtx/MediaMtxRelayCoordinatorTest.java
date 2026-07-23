package com.lasercyber.lws.ui.network.mediamtx;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

public class MediaMtxRelayCoordinatorTest {

    @After
    public void tearDown() {
        MediaMtxRelayCoordinator.getInstance().resetForTest();
    }

    @Test
    public void extraLease_acquireAndRelease() {
        MediaMtxRelayCoordinator c = MediaMtxRelayCoordinator.getInstance();
        Assert.assertEquals(0, c.extraLeaseCountForTest());
        c.acquireLease();
        Assert.assertEquals(1, c.extraLeaseCountForTest());
        c.acquireLease();
        Assert.assertEquals(2, c.extraLeaseCountForTest());
        c.releaseLease();
        Assert.assertEquals(1, c.extraLeaseCountForTest());
        c.releaseLease();
        Assert.assertEquals(0, c.extraLeaseCountForTest());
    }

    @Test
    public void releaseExtraLease_doesNotClearLanPreviewHold() {
        MediaMtxRelayCoordinator c = MediaMtxRelayCoordinator.getInstance();
        c.startForLanPreview();
        Assert.assertTrue(c.lanPreviewHoldForTest());
        c.acquireLease();
        c.releaseLease();
        Assert.assertTrue(c.lanPreviewHoldForTest());
    }
}
