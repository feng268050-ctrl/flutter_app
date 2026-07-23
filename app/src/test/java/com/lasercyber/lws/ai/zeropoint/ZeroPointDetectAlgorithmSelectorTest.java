package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectAlgorithmSelector;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class ZeroPointDetectAlgorithmSelectorTest {

    @Test
    public void framesPerRound_isTen() {
        assertEquals(10, ZeroPointDetectAlgorithmSelector.FRAMES_PER_DETECT_ROUND);
    }
}
