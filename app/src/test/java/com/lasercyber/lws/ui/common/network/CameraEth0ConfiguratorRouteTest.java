package com.lasercyber.lws.ui.common.network;

import org.junit.Assert;
import org.junit.Test;

import java.util.List;

public class CameraEth0ConfiguratorRouteTest {

    @Test
    public void hostRouteCommands_onlyUseSlash32() {
        List<String> commands = CameraEth0Configurator.buildRouteCommands(
                "192.168.1.0/24",
                "192.168.1.234",
                "192.168.1.100",
                CameraRoutePolicy.CAMERA_HOST_ROUTE);
        Assert.assertEquals(2, commands.size());
        Assert.assertTrue(commands.get(0).contains("192.168.1.100/32"));
        Assert.assertFalse(commands.get(0).contains("192.168.1.0/24"));
    }

    @Test
    public void subnetRouteCommands_useSlash24() {
        List<String> commands = CameraEth0Configurator.buildRouteCommands(
                "192.168.1.0/24",
                "192.168.1.234",
                "192.168.1.100",
                CameraRoutePolicy.CAMERA_SUBNET_ROUTE);
        Assert.assertTrue(commands.get(0).contains("192.168.1.0/24"));
    }
}
