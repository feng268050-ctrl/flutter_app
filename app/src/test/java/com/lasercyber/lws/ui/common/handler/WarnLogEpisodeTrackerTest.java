package com.lasercyber.lws.ui.common.handler;

import org.junit.After;
import org.junit.Assert;
import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;

public class WarnLogEpisodeTrackerTest {

    @After
    public void tearDown() {
        WarnLogEpisodeTracker.resetForTest();
    }

    @Test
    public void resolveInsertCodes_insertsOnlyOnRisingEdge() {
        Assert.assertEquals(
                new HashSet<>(Collections.singletonList("A001")),
                WarnLogEpisodeTracker.resolveInsertCodes(
                        Collections.singletonList("A001"),
                        Collections.emptyList()));

        Assert.assertTrue(
                WarnLogEpisodeTracker.resolveInsertCodes(
                        Collections.singletonList("A001"),
                        Collections.emptyList()).isEmpty());
    }

    @Test
    public void resolveInsertCodes_skipsReinsertAfterClearWhileFaultOngoing() {
        WarnLogEpisodeTracker.resolveInsertCodes(
                Arrays.asList("A001", "B002"),
                Collections.emptyList());

        Assert.assertTrue(
                WarnLogEpisodeTracker.resolveInsertCodes(
                        Arrays.asList("A001", "B002"),
                        Collections.emptyList()).isEmpty());
    }

    @Test
    public void resolveInsertCodes_hydratesFromExistingDbRowsWithoutInsert() {
        Assert.assertTrue(
                WarnLogEpisodeTracker.resolveInsertCodes(
                        Collections.singletonList("A001"),
                        Collections.singletonList("A001")).isEmpty());
        Assert.assertTrue(
                WarnLogEpisodeTracker.resolveInsertCodes(
                        Collections.singletonList("A001"),
                        Collections.emptyList()).isEmpty());
    }

    @Test
    public void notifyFaultCleared_allowsReinsertAfterFaultReturns() {
        WarnLogEpisodeTracker.resolveInsertCodes(
                Collections.singletonList("A001"),
                Collections.emptyList());
        Assert.assertTrue(WarnLogEpisodeTracker.notifyFaultCleared("A001"));

        Assert.assertEquals(
                new HashSet<>(Collections.singletonList("A001")),
                WarnLogEpisodeTracker.resolveInsertCodes(
                        Collections.singletonList("A001"),
                        Collections.emptyList()));
    }
}
