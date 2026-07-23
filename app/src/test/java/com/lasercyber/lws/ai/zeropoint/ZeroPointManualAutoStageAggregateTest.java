package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectClusterReducer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;

/**
 * Mirrors {@link ZeroPointManualAutoStageAggregate#from} reducer wiring.
 */
public class ZeroPointManualAutoStageAggregateTest {

    @Test
    public void stageLikeOnlineSamples_useClusterRepresentative() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(0.0, 1.0, 50.0, 2.0),
                Arrays.asList(0.0, 0.0, 0.0, 1.0));
        assertTrue(result.hasRepresentative);
        assertEquals(3, result.winnerClusterSize);
        assertFalse(result.usedFullSampleClustering);
    }

    @Test
    public void emptyStageSamples_remainEmpty() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Collections.emptyList(),
                Collections.emptyList());
        assertFalse(result.hasRepresentative);
    }
}
