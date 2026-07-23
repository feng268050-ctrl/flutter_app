package com.lasercyber.lws.ui.common.upgrade;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class ProcessLibraryAssetSelectorTest {

    @Test
    public void normalizeDeviceModel_stripsLaserCyberPrefixAndWhitespace() {
        String normalized = ProcessLibraryAssetSelector.normalizeDeviceModel("  LaserCyber   L1   Pro ");
        Assert.assertEquals("L1 Pro", normalized);
    }

    @Test
    public void select_matchesModelIgnoringCaseAndWhitespace() {
        ProcessLibraryAssetSelector.SelectionResult result = ProcessLibraryAssetSelector.select(
                List.of("l1   pro.xlsx", "L1.xlsx"),
                "LaserCyber L1 Pro"
        );
        Assert.assertEquals("l1   pro.xlsx", result.selectedFileName);
        Assert.assertFalse(result.fallbackUsed);
    }

    @Test
    public void select_usesSingleFileWithoutModelMatch() {
        ProcessLibraryAssetSelector.SelectionResult result = ProcessLibraryAssetSelector.select(
                List.of("工艺库_v1.0.1-beta.xlsx"),
                "LaserCyber Unknown"
        );
        Assert.assertEquals("工艺库_v1.0.1-beta.xlsx", result.selectedFileName);
        Assert.assertFalse(result.fallbackUsed);
    }

    @Test
    public void select_fallbackUsesStableSortedFirst() {
        ProcessLibraryAssetSelector.SelectionResult result = ProcessLibraryAssetSelector.select(
                List.of("L2.xlsx", "L1.xlsx"),
                "LaserCyber L1 Pro"
        );
        Assert.assertEquals("L1.xlsx", result.selectedFileName);
        Assert.assertTrue(result.fallbackUsed);
    }
}
