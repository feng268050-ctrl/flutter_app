package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

public class CameraPingHealthTest {

    @Before
    @After
    public void reset() {
        CameraPingHealth.getInstance().resetForTest();
        CameraPingHealth.getInstance().setReachableForTest(true);
    }

    @Test
    public void isReachable_defaultOptimisticTrue() {
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void onProbeResult_firstFailFromOptimisticStart_marksUnreachable() {
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void probeAsync_success_setsReachableAfterStableProbes() throws InterruptedException {
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> true);
        for (int i = 0; i < CameraPingHealth.RECOVERY_STABLE_PINGS; i++) {
            CameraPingHealth.getInstance().probeAsync();
            Thread.sleep(300L);
        }
        CountDownLatch latch = new CountDownLatch(1);
        Thread waiter = new Thread(() -> {
            CameraPingHealth.getInstance().awaitReachable(2000L);
            latch.countDown();
        });
        waiter.start();
        assertTrue(latch.await(3, TimeUnit.SECONDS));
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void onProbeResult_singleSuccessWhileFault_doesNotRecover() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        CameraPingHealth.getInstance().onProbeResultForTest(true);
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void onProbeResult_stableSuccessRecoversFromFault() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        for (int i = 0; i < CameraPingHealth.RECOVERY_STABLE_PINGS; i++) {
            CameraPingHealth.getInstance().onProbeResultForTest(true);
        }
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void onProbeResult_singleFailAfterRecovery_refaultsImmediately() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        for (int i = 0; i < CameraPingHealth.RECOVERY_STABLE_PINGS; i++) {
            CameraPingHealth.getInstance().onProbeResultForTest(true);
        }
        assertTrue(CameraPingHealth.getInstance().isReachable());
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void onProbeResult_failureFromReachable_failsImmediately() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void probeAsync_failure_clearsReachable() throws InterruptedException {
        CameraPingHealth.getInstance().setReachableForTest(true);
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> false);
        CameraPingHealth.getInstance().probeAsync();
        CountDownLatch latch = new CountDownLatch(1);
        Thread waiter = new Thread(() -> {
            while (CameraPingHealth.getInstance().isReachable()) {
                try {
                    Thread.sleep(20L);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
            latch.countDown();
        });
        waiter.start();
        assertTrue(latch.await(3, TimeUnit.SECONDS));
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void probeBlocking_whenOptimisticallyReachable_runsPingAndFails() {
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> false);
        assertFalse(CameraPingHealth.getInstance().probeBlocking());
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void probeBlocking_whenOptimisticallyReachable_runsPingAndPasses() {
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> true);
        assertTrue(CameraPingHealth.getInstance().probeBlocking());
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void endEth0Configure_pingOk_countsTowardRecovery() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        CameraPingHealth.getInstance().endEth0ConfigureForTest(true);
        assertFalse(CameraPingHealth.getInstance().isReachable());
        CameraPingHealth.getInstance().onProbeResultForTest(true);
        CameraPingHealth.getInstance().onProbeResultForTest(true);
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void endEth0Configure_pingFail_whenAlreadyFault_staysFault() {
        CameraPingHealth.getInstance().setReachableForTest(false);
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        CameraPingHealth.getInstance().endEth0ConfigureForTest(false);
        assertFalse(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void endEth0Configure_pingFail_whenHealthy_keepsReachable() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        CameraPingHealth.getInstance().endEth0ConfigureForTest(false);
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void eth0Configure_ignoresProbeFailures() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        assertTrue(CameraPingHealth.getInstance().isReachable());
        CameraPingHealth.getInstance().endEth0ConfigureForTest(true);
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void probeAsync_skippedDuringEth0Configure() throws InterruptedException {
        AtomicInteger pingCount = new AtomicInteger();
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> {
            pingCount.incrementAndGet();
            return false;
        });
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        CameraPingHealth.getInstance().probeAsync();
        Thread.sleep(300L);
        assertEquals(0, pingCount.get());
        CameraPingHealth.getInstance().endEth0ConfigureForTest(true);
    }

    @Test
    public void probeBlocking_duringEth0Configure_returnsCachedReachable() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> false);
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        assertTrue(CameraPingHealth.getInstance().probeBlocking());
        assertTrue(CameraPingHealth.getInstance().isReachable());
        CameraPingHealth.getInstance().endEth0ConfigureForTest(true);
    }

    @Test
    public void postConfigureQuiet_ignoresFailures() {
        CameraPingHealth.getInstance().setReachableForTest(true);
        CameraPingHealth.getInstance().beginEth0ConfigureForTest();
        CameraPingHealth.getInstance().endEth0ConfigureForTest(true);
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        CameraPingHealth.getInstance().onProbeResultForTest(false);
        assertTrue(CameraPingHealth.getInstance().isReachable());
    }

    @Test
    public void probeAsync_coalescesInFlight() throws InterruptedException {
        AtomicInteger pingCount = new AtomicInteger();
        CameraPingHealth.getInstance().setPingExecutorForTest(host -> {
            pingCount.incrementAndGet();
            try {
                Thread.sleep(200L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return true;
        });
        CameraPingHealth.getInstance().probeAsync();
        assertTrue(CameraPingHealth.getInstance().isProbeInFlightForTest());
        CameraPingHealth.getInstance().probeAsync();
        CameraPingHealth.getInstance().probeAsync();
        Thread.sleep(400L);
        assertEquals(1, pingCount.get());
    }
}
