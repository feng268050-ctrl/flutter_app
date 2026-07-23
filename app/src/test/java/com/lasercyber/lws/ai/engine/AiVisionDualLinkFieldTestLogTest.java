package com.lasercyber.lws.ai.engine;
import com.lasercyber.lws.ai.engine.AiVisionDualLinkFieldTestLog;

import org.junit.Assert;
import org.junit.Test;

public final class AiVisionDualLinkFieldTestLogTest {

    @Test
    public void overlaySyncPassThreshold_is300ms() {
        Assert.assertEquals(300L, AiVisionDualLinkFieldTestLog.OVERLAY_SYNC_PASS_MS);
    }

    @Test
    public void resetSession_doesNotThrow() {
        AiVisionDualLinkFieldTestLog.resetSession();
    }
}
