package com.lasercyber.lws.ui.common.network.wifi;

import org.junit.Assert;
import org.junit.Test;

public class WifiSubnetUtilsTest {

    @Test
    public void maskToPrefixLength_acceptsDottedMask() {
        Assert.assertEquals(24, WifiSubnetUtils.maskToPrefixLength("255.255.255.0"));
    }

    @Test
    public void maskToPrefixLength_acceptsSlashPrefix() {
        Assert.assertEquals(24, WifiSubnetUtils.maskToPrefixLength("/24"));
    }

    @Test
    public void prefixLengthToMask_roundTrip() {
        Assert.assertEquals("255.255.255.0", WifiSubnetUtils.prefixLengthToMask(24));
    }

    @Test
    public void sameSubnet_detectsOverlap() {
        Assert.assertTrue(WifiSubnetUtils.sameSubnet("192.168.1.50", "192.168.1.1", 24));
        Assert.assertFalse(WifiSubnetUtils.sameSubnet("10.0.0.50", "192.168.1.1", 24));
    }
}
