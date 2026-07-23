package com.lasercyber.lws.ui.ai;

import static org.junit.Assert.assertFalse;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import com.lasercyber.lws.ai.NativeBridge;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

@RunWith(AndroidJUnit4.class)
public class NativeBridgeGuardInstrumentedTest {

    @Test
    public void guardedRknnStainDetectFromStream_concurrentInvalidHandle_doesNotCrash() throws Exception {
        ByteBuffer frame = ByteBuffer.allocateDirect(1280 * 720 * 3 / 2);
        frame.order(ByteOrder.nativeOrder());
        AtomicBoolean first = new AtomicBoolean(true);
        AtomicBoolean second = new AtomicBoolean(true);
        CountDownLatch latch = new CountDownLatch(2);

        Thread t1 = new Thread(() -> {
            first.set(NativeBridge.guardedRknnStainDetectFromStream(99999L, frame.duplicate(), 1280, 720));
            latch.countDown();
        }, "guard-test-1");
        Thread t2 = new Thread(() -> {
            second.set(NativeBridge.guardedRknnStainDetectFromStream(99999L, frame.duplicate(), 1280, 720));
            latch.countDown();
        }, "guard-test-2");

        t1.start();
        t2.start();

        latch.await(5, TimeUnit.SECONDS);
        assertFalse(first.get());
        assertFalse(second.get());
    }

    @Test
    public void guardedStopDestroy_invalidHandle_doesNotCrash() {
        NativeBridge.guardedStopAndDestroy(99999L);
    }
}
