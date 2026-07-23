package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.stain.AiStainDetectCoordinator;

import org.junit.Assert;
import org.junit.Test;

public class AiStainDetectCoordinatorTest {

    @Test
    public void tryBegin_busyWhenInFlight() {
        AiStainDetectCoordinator c = new AiStainDetectCoordinator();
        Assert.assertTrue(c.tryBegin());
        Assert.assertFalse(c.tryBegin());
        c.end();
        Assert.assertTrue(c.tryBegin());
    }
}
