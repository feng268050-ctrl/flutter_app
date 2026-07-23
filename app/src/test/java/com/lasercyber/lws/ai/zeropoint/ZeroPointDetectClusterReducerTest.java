package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectClusterReducer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public class ZeroPointDetectClusterReducerTest {

    @Test
    public void emptyInput_returnsEmpty() {
        ZeroPointDetectClusterReducer.Result result =
                ZeroPointDetectClusterReducer.reduce(Collections.emptyList(), Collections.emptyList());
        assertFalse(result.hasRepresentative);
    }

    @Test
    public void nearbySamples_mergeIntoOneCluster() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(0.0, 2.0, -1.0),
                Arrays.asList(0.0, 1.0, 2.0));
        assertTrue(result.hasRepresentative);
        assertEquals(1, result.clusterCount);
        assertEquals(3, result.winnerClusterSize);
        assertEquals(0.0, result.representativeOffsetX, 1e-9);
        assertEquals(0.0, result.representativeOffsetY, 1e-9);
    }

    @Test
    public void distantSamples_pickLargerCluster() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(0.0, 0.0, 0.0, 20.0),
                Arrays.asList(0.0, 1.0, 2.0, 0.0));
        assertTrue(result.hasRepresentative);
        assertEquals(0.0, result.representativeOffsetX, 1e-9);
        assertEquals(1.0, result.representativeOffsetY, 1e-9);
        assertEquals(3, result.winnerClusterSize);
    }

    @Test
    public void representative_isNearestToCentroid() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(0.0, 4.0, 0.0),
                Arrays.asList(0.0, 0.0, 4.0));
        assertTrue(result.hasRepresentative);
        assertEquals(0.0, result.representativeOffsetX, 1e-9);
        assertEquals(0.0, result.representativeOffsetY, 1e-9);
    }

    @Test
    public void anchorRejectsSubsequentOutlier_whenFullClusterNotLarger() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(0.0, 1.0, 25.0),
                Arrays.asList(0.0, 0.0, 0.0));
        assertTrue(result.hasRepresentative);
        assertEquals(1, result.anchorRejectedCount);
        assertEquals(0.0, result.representativeOffsetX, 1e-9);
        assertFalse(result.usedFullSampleClustering);
    }

    @Test
    public void fullSampleClusteringOverridesAnchor_whenLargerClusterExists() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(50.0, 0.0, 1.0, 2.0, -1.0),
                Arrays.asList(0.0, 0.0, 1.0, 2.0, 2.0));
        assertTrue(result.hasRepresentative);
        assertTrue(result.usedFullSampleClustering);
        assertEquals(4, result.winnerClusterSize);
        assertEquals(4, result.anchorRejectedCount);
    }

    @Test
    public void tieBreakOnClusterSize_usesLexicographicMean() {
        List<ZeroPointDetectClusterReducer.Observation> observations = Arrays.asList(
                new ZeroPointDetectClusterReducer.Observation(-25.0, 0.0, 0),
                new ZeroPointDetectClusterReducer.Observation(-23.0, 0.0, 1),
                new ZeroPointDetectClusterReducer.Observation(23.0, 0.0, 2),
                new ZeroPointDetectClusterReducer.Observation(25.0, 0.0, 3));
        ZeroPointDetectClusterReducer.Result result =
                ZeroPointDetectClusterReducer.reduceObservations(observations);
        assertTrue(result.hasRepresentative);
        assertEquals(-25.0, result.representativeOffsetX, 1e-9);
    }

    @Test
    public void representativeTieBreak_prefersEarliestArrivalIndex() {
        ZeroPointDetectClusterReducer.Result result = ZeroPointDetectClusterReducer.reduce(
                Arrays.asList(1.0, -1.0),
                Arrays.asList(0.0, 0.0));
        assertTrue(result.hasRepresentative);
        assertEquals(1.0, result.representativeOffsetX, 1e-9);
    }
}
