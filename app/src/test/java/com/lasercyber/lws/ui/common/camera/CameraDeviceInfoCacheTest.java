package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.lasercyber.lws.ui.network.http.remote.CameraRemote;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.concurrent.atomic.AtomicInteger;

public class CameraDeviceInfoCacheTest {

    @Before
    public void setUp() {
        CameraPingHealth.getInstance().resetForTest();
        CameraDeviceInfoCache.resetForTest();
        CameraDeviceInfoCache.setDelaySchedulerForTest((delayMs, task) -> task.run());
        CameraPingHealth.getInstance().setReachableForTest(true);
    }

    @After
    public void resetCache() {
        CameraPingHealth.getInstance().resetForTest();
        CameraDeviceInfoCache.resetForTest();
    }

    @Test
    public void getDisplay_whenEmpty_returnsDash() {
        assertEquals(CameraRemote.CAMERA_VERSION_UNAVAILABLE, CameraDeviceInfoCache.getDisplay());
    }

    @Test
    public void applyDisplayForTest_storesNormalizedValue() {
        CameraDeviceInfoCache.applyDisplayForTest("1.0.5");
        assertEquals("1.0.5", CameraDeviceInfoCache.getDisplay());
        assertTrue(CameraDeviceInfoCache.isVersionResolvedForTest());
    }

    @Test
    public void applyDisplayForTest_failurePlaceholder_storesDash() {
        CameraDeviceInfoCache.applyDisplayForTest(CameraRemote.CAMERA_VERSION_UNAVAILABLE);
        assertEquals(CameraRemote.CAMERA_VERSION_UNAVAILABLE, CameraDeviceInfoCache.getDisplay());
        assertFalse(CameraDeviceInfoCache.isVersionResolvedForTest());
    }

    @Test
    public void refreshWhileInFlight_coalescesPendingCallbacks() {
        CameraDeviceInfoCache.beginRefreshForTest();
        AtomicInteger completed = new AtomicInteger();
        CameraDeviceInfoCache.refresh(null, completed::incrementAndGet);
        assertTrue(CameraDeviceInfoCache.isRefreshInFlightForTest());
        assertEquals(1, CameraDeviceInfoCache.pendingCallbackCountForTest());
        assertEquals(0, completed.get());
        CameraDeviceInfoCache.completeRefreshForTest("2.0.0");
        assertFalse(CameraDeviceInfoCache.isRefreshInFlightForTest());
        assertEquals(1, completed.get());
        assertEquals("2.0.0", CameraDeviceInfoCache.getDisplay());
    }

    @Test
    public void refresh_whenVersionResolved_skipsFetcher() {
        CameraDeviceInfoCache.applyDisplayForTest("3.0.0");
        AtomicInteger fetchCount = new AtomicInteger();
        CameraDeviceInfoCache.setDeviceInfoFetcherForTest((ctx, callback) -> {
            fetchCount.incrementAndGet();
            callback.onResult("9.9.9");
        });
        AtomicInteger completed = new AtomicInteger();
        CameraDeviceInfoCache.refresh(null, completed::incrementAndGet);
        assertEquals(0, fetchCount.get());
        assertEquals(1, completed.get());
        assertEquals("3.0.0", CameraDeviceInfoCache.getDisplay());
    }

    @Test
    public void backoff_succeedsOnLaterAttempt() {
        AtomicInteger fetchCount = new AtomicInteger();
        CameraDeviceInfoCache.setDeviceInfoFetcherForTest((ctx, callback) -> {
            if (fetchCount.incrementAndGet() < 3) {
                callback.onResult(CameraRemote.CAMERA_VERSION_UNAVAILABLE);
            } else {
                callback.onResult("4.2.1");
            }
        });
        CameraDeviceInfoCache.refreshBackoffForTest(null);
        assertEquals(3, fetchCount.get());
        assertEquals("4.2.1", CameraDeviceInfoCache.getDisplay());
        assertTrue(CameraDeviceInfoCache.isVersionResolvedForTest());
    }

    @Test
    public void backoff_exhaustedLeavesDash() {
        AtomicInteger fetchCount = new AtomicInteger();
        CameraDeviceInfoCache.setDeviceInfoFetcherForTest(
                (ctx, callback) -> {
                    fetchCount.incrementAndGet();
                    callback.onResult(CameraRemote.CAMERA_VERSION_UNAVAILABLE);
                });
        CameraDeviceInfoCache.refreshBackoffForTest(null);
        assertEquals(5, fetchCount.get());
        assertEquals(CameraRemote.CAMERA_VERSION_UNAVAILABLE, CameraDeviceInfoCache.getDisplay());
        assertFalse(CameraDeviceInfoCache.isVersionResolvedForTest());
        AtomicInteger fetchAfterExhaustion = new AtomicInteger();
        CameraDeviceInfoCache.setDeviceInfoFetcherForTest((ctx, callback) -> {
            fetchAfterExhaustion.incrementAndGet();
            callback.onResult("5.0.0");
        });
        CameraDeviceInfoCache.refreshBackoffForTest(null);
        assertEquals(0, fetchAfterExhaustion.get());
    }

    @Test
    public void refresh_whenPingUnreachable_doesNotFetchUntilReachable() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        AtomicInteger fetchCount = new AtomicInteger();
        CameraDeviceInfoCache.setDeviceInfoFetcherForTest((ctx, callback) -> {
            fetchCount.incrementAndGet();
            callback.onResult("6.0.0");
        });
        CameraDeviceInfoCache.refreshBackoffForTest(null);
        assertEquals(0, fetchCount.get());
        CameraPingHealth.getInstance().setReachableForTest(true);
        assertEquals(1, fetchCount.get());
        assertEquals("6.0.0", CameraDeviceInfoCache.getDisplay());
    }

    @Test
    public void clearAndRefresh_retriesAfterResolved() {
        CameraDeviceInfoCache.applyDisplayForTest("1.0.0");
        AtomicInteger fetchCount = new AtomicInteger();
        CameraDeviceInfoCache.setDeviceInfoFetcherForTest((ctx, callback) -> {
            fetchCount.incrementAndGet();
            callback.onResult("2.0.0");
        });
        CameraDeviceInfoCache.clearAndRefresh(null);
        CameraDeviceInfoCache.refreshBackoffForTest(null);
        assertEquals(1, fetchCount.get());
        assertEquals("2.0.0", CameraDeviceInfoCache.getDisplay());
    }
}
