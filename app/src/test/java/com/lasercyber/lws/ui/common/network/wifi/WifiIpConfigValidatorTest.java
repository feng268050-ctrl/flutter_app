package com.lasercyber.lws.ui.common.network.wifi;

import org.junit.Assert;
import org.junit.Test;

public class WifiIpConfigValidatorTest {

    @Test
    public void dhcp_alwaysValid() {
        Assert.assertTrue(WifiIpConfigValidator.validate(WifiIpConfig.dhcp(), null).valid);
    }

    @Test
    public void static_rejectsCameraIpConflict() {
        WifiIpConfig config = WifiIpConfig.staticIp(
                "192.168.1.100", 24, "192.168.1.1", "8.8.8.8", null);
        WifiIpConfigValidator.Result result = WifiIpConfigValidator.validate(config, null);
        Assert.assertFalse(result.valid);
        Assert.assertEquals("conflicts_with_camera_ip", result.reason);
    }

    @Test
    public void static_validSample() {
        WifiIpConfig config = WifiIpConfig.staticIp(
                "192.168.10.50", 24, "192.168.10.1", "8.8.8.8", null);
        Assert.assertTrue(WifiIpConfigValidator.validate(config, null).valid);
    }
}
