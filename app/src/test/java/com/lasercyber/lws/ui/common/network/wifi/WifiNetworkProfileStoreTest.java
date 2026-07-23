package com.lasercyber.lws.ui.common.network.wifi;

import org.junit.Assert;
import org.junit.Test;

public class WifiNetworkProfileStoreTest {

    @Test
    public void encodeDecode_dhcp() {
        String raw = WifiNetworkProfileStore.encode(WifiIpConfig.dhcp());
        WifiNetworkProfile profile = WifiNetworkProfileStore.decode(raw, "Office", "WPA2");
        Assert.assertNotNull(profile);
        Assert.assertEquals(WifiIpConfig.Mode.DHCP, profile.ipConfig.mode);
    }

    @Test
    public void encodeDecode_static() {
        WifiIpConfig config = WifiIpConfig.staticIp(
                "192.168.10.50", 24, "192.168.10.1", "8.8.8.8", "1.1.1.1");
        String raw = WifiNetworkProfileStore.encode(config);
        WifiNetworkProfile profile = WifiNetworkProfileStore.decode(raw, "Office", "WPA2");
        Assert.assertNotNull(profile);
        Assert.assertEquals(config, profile.ipConfig);
    }
}
