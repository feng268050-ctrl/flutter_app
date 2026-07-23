package com.lasercyber.lws.ui.activitys.engineer.mode.model;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import org.junit.Assert;
import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;

public class WarnTableViewModelInsertTest {

    @Test
    public void filterInsertCandidates_insertsOnlyResolvedCodes() {
        List<WarnTable> active = rows("A001", "C002");
        List<WarnTable> inserts = WarnTableViewModel.filterInsertCandidates(
                active,
                Collections.emptyList(),
                new HashSet<>(Collections.singletonList("C002")));
        Assert.assertEquals(1, inserts.size());
        Assert.assertEquals("C002", inserts.get(0).getCode());
    }

    @Test
    public void filterInsertCandidates_skipsWhenDbRowExists() {
        WarnTable existing = new WarnTable();
        existing.setCode("A001");
        existing.setId(7L);
        List<WarnTable> inserts = WarnTableViewModel.filterInsertCandidates(
                rows("A001"),
                Collections.singletonList(existing),
                new HashSet<>(Collections.singletonList("A001")));
        Assert.assertTrue(inserts.isEmpty());
    }

    private static List<WarnTable> rows(String... codes) {
        WarnTable[] out = new WarnTable[codes.length];
        for (int i = 0; i < codes.length; i++) {
            WarnTable row = new WarnTable();
            row.setCode(codes[i]);
            out[i] = row;
        }
        return Arrays.asList(out);
    }
}
