package com.lasercyber.lws.ai.stream;
import com.lasercyber.lws.ai.stream.NativeStreamDetectCoordinator;

import org.junit.Assert;
import org.junit.Test;

import java.util.HashSet;
import java.util.Set;

public final class NativeStreamDetectCoordinatorHolderTest {

    @Test
    public void shouldKeepPipelineRunning_whenAnyHolderActive() {
        Set<String> holders = new HashSet<>();
        Assert.assertFalse(NativeStreamDetectCoordinator.shouldKeepPipelineRunning(holders));
        holders.add(NativeStreamDetectCoordinator.HOLDER_WELD);
        Assert.assertTrue(NativeStreamDetectCoordinator.shouldKeepPipelineRunning(holders));
        holders.add(NativeStreamDetectCoordinator.HOLDER_AI_VISION);
        Assert.assertTrue(NativeStreamDetectCoordinator.shouldKeepPipelineRunning(holders));
        holders.remove(NativeStreamDetectCoordinator.HOLDER_WELD);
        Assert.assertTrue(NativeStreamDetectCoordinator.shouldKeepPipelineRunning(holders));
        holders.clear();
        Assert.assertFalse(NativeStreamDetectCoordinator.shouldKeepPipelineRunning(holders));
    }
}
