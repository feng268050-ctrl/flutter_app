package com.lasercyber.lws.ai;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public class NativeBridgeGuardTest {

    @Test
    public void validateFrameInput_acceptsExactNv12Size() {
        int width = 1280;
        int height = 720;
        ByteBuffer data = directNv12(width * height * 3 / 2);

        String error = NativeBridge.validateFrameInput(data, width, height, NativeBridge.SessionState.RUNNING);

        assertNull(error);
    }

    @Test
    public void validateFrameInput_rejectsDestroyedState() {
        ByteBuffer data = directNv12(6);

        String error = NativeBridge.validateFrameInput(data, 2, 2, NativeBridge.SessionState.DESTROYED);

        assertNotNull(error);
        assertTrue(error.contains("state"));
    }

    @Test
    public void validateFrameInput_rejectsSizeMismatch() {
        int width = 640;
        int height = 480;
        ByteBuffer data = directNv12(10);

        String error = NativeBridge.validateFrameInput(data, width, height, NativeBridge.SessionState.RUNNING);

        assertNotNull(error);
        assertTrue(error.contains("mismatch"));
    }

    private static ByteBuffer directNv12(int capacity) {
        ByteBuffer buffer = ByteBuffer.allocateDirect(capacity);
        buffer.order(ByteOrder.nativeOrder());
        return buffer;
    }
}
