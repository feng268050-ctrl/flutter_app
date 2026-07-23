package com.lasercyber.lws.ui.common.network;

import org.junit.Assert;
import org.junit.Test;

public class CameraRoutePolicyResolverTest {

    @Test
    public void overlap_usesHostRoute() {
        Assert.assertEquals(
                CameraRoutePolicy.CAMERA_HOST_ROUTE,
                CameraRoutePolicyResolver.resolve("192.168.1.50", "192.168.1.100"));
    }

    @Test
    public void noOverlap_usesSubnetRoute() {
        Assert.assertEquals(
                CameraRoutePolicy.CAMERA_SUBNET_ROUTE,
                CameraRoutePolicyResolver.resolve("10.0.0.50", "192.168.1.100"));
    }

    @Test
    public void nullWlan_usesSubnetRoute() {
        Assert.assertEquals(
                CameraRoutePolicy.CAMERA_SUBNET_ROUTE,
                CameraRoutePolicyResolver.resolve(null, "192.168.1.100"));
    }
}
