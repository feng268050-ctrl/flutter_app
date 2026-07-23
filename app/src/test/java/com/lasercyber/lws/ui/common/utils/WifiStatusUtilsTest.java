package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import org.junit.Test;

public class WifiStatusUtilsTest {

    @Test
    public void formatIpAddress_matchesWifiDetailsActivity() {
        assertEquals("234.1.168.192", WifiStatusUtils.formatIpAddress(0xC0A801EA));
    }

    @Test
    public void formatIpOrNull_returnsNullForZero() {
        assertNull(WifiStatusUtils.formatIpOrNull(0));
    }

    @Test
    public void deriveSecurityType_mapsCapabilities() {
        assertEquals("WPA3", WifiStatusUtils.deriveSecurityType("[WPA3-SAE-CCMP]"));
        assertEquals("WPA2", WifiStatusUtils.deriveSecurityType("[WPA2-PSK-CCMP]"));
        assertEquals("WPA", WifiStatusUtils.deriveSecurityType("[WPA-PSK-CCMP]"));
        assertEquals("WEP", WifiStatusUtils.deriveSecurityType("[WEP]"));
        assertEquals("Open", WifiStatusUtils.deriveSecurityType("[ESS]"));
        assertNull(WifiStatusUtils.deriveSecurityType(null));
        assertNull(WifiStatusUtils.deriveSecurityType(""));
    }

    @Test
    public void formatMacOrNull_masksUnavailable() {
        assertNull(WifiStatusUtils.formatMacOrNull(null));
        assertNull(WifiStatusUtils.formatMacOrNull(""));
        assertNull(WifiStatusUtils.formatMacOrNull("02:00:00:00:00:00"));
        assertEquals("aa:bb:cc:dd:ee:ff", WifiStatusUtils.formatMacOrNull("aa:bb:cc:dd:ee:ff"));
    }
}
