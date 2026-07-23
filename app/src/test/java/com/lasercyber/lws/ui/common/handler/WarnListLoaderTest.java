package com.lasercyber.lws.ui.common.handler;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import org.junit.Assert;
import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public class WarnListLoaderTest {

    @Test
    public void applyInsertIds_setsRowIdsFromBatchResult() {
        WarnTable a = new WarnTable();
        a.setCode("C002");
        WarnTable b = new WarnTable();
        b.setCode("A001");
        WarnListLoader.applyInsertIds(Arrays.asList(a, b), Arrays.asList(10L, 11L));
        Assert.assertEquals(Long.valueOf(10L), a.getId());
        Assert.assertEquals(Long.valueOf(11L), b.getId());
    }

    @Test
    public void applyInsertIds_ignoresNonPositiveIds() {
        WarnTable row = new WarnTable();
        WarnListLoader.applyInsertIds(Collections.singletonList(row), Collections.singletonList(-1L));
        Assert.assertNull(row.getId());
    }

}
