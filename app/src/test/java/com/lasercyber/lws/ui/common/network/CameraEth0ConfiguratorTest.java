package com.lasercyber.lws.ui.common.network;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.List;

public class CameraEth0ConfiguratorTest {

    @Test
    public void buildRouteCommands_includesFallbacks() {
        List<String> cmds = CameraEth0Configurator.buildRouteCommands(
                "192.168.1.0/24", "192.168.1.234", "192.168.1.100");
        assertEquals(4, cmds.size());
        assertTrue(cmds.get(0).contains("replace 192.168.1.0/24 dev eth0 src 192.168.1.234"));
        assertTrue(cmds.get(1).contains("replace 192.168.1.0/24 dev eth0"));
        assertTrue(cmds.get(2).contains("add 192.168.1.0/24 dev eth0"));
        assertTrue(cmds.get(3).contains("replace 192.168.1.100/32 dev eth0"));
    }

    @Test
    public void result_success_requiresAddressAndRouteOrPing() {
        CameraEth0Configurator.Result okRoute = new CameraEth0Configurator.Result(
                "192.168.1.100", "192.168.1.234", "10.0.0.1",
                true, true, true, false, false, "192.168.1.234/24");
        assertTrue(okRoute.success());

        CameraEth0Configurator.Result okPing = new CameraEth0Configurator.Result(
                "192.168.1.100", "192.168.1.234", null,
                true, true, false, true, false, "192.168.1.234/24");
        assertTrue(okPing.success());

        CameraEth0Configurator.Result bad = new CameraEth0Configurator.Result(
                "192.168.1.100", "192.168.1.234", null,
                true, true, false, false, false, null);
        assertFalse(bad.success());
    }

    @Test
    public void parseEth0Ipv4Cidr_fromIpAddrShow() {
        String sample = "2: eth0    inet 192.168.1.234/24 brd 192.168.1.255 scope global eth0\n";
        assertEquals("192.168.1.234/24", CameraEth0Configurator.parseEth0Ipv4Cidr(sample));
    }

    @Test
    public void parseEth0Ipv4Cidr_ignoresInet6() {
        String sample = "inet6 fe80::1/64 scope link\ninet 192.168.1.253/24 scope global eth0\n";
        assertEquals("192.168.1.253/24", CameraEth0Configurator.parseEth0Ipv4Cidr(sample));
    }
}
