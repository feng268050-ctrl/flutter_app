package com.lasercyber.lws.ui.common.network.wifi;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.net.wifi.ScanResult;

import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public class WifiScanResultAggregatorTest {

    @Test
    public void normalizeSsid_stripsQuotesAndRejectsUnknown() {
        assertEquals("Office-Net", WifiScanResultAggregator.normalizeSsid("\"Office-Net\""));
        assertNull(WifiScanResultAggregator.normalizeSsid("<unknown ssid>"));
        assertNull(WifiScanResultAggregator.normalizeSsid(""));
        assertNull(WifiScanResultAggregator.normalizeSsid(null));
    }

    @Test
    public void aggregate_collapsesSameSsidToStrongestRssi() {
        ScanResult weak = scan("Office-Net", "aa:bb:cc:dd:ee:01", -80);
        ScanResult strong = scan("Office-Net", "aa:bb:cc:dd:ee:02", -65);
        ScanResult other = scan("Guest", "aa:bb:cc:dd:ee:03", -70);

        List<WifiScanResultAggregator.AggregatedEntry> aggregated =
                WifiScanResultAggregator.aggregate(Arrays.asList(weak, strong, other), null);

        assertEquals(2, aggregated.size());
        assertEquals("Office-Net", aggregated.get(0).ssid);
        assertEquals(-65, aggregated.get(0).representative.level);
        assertEquals("Guest", aggregated.get(1).ssid);
    }

    @Test
    public void aggregate_excludesConnectedSsid() {
        ScanResult office = scan("Office-Net", "aa:bb:cc:dd:ee:01", -60);
        ScanResult guest = scan("Guest", "aa:bb:cc:dd:ee:02", -70);

        List<WifiScanResultAggregator.AggregatedEntry> aggregated =
                WifiScanResultAggregator.aggregate(Arrays.asList(office, guest), "Office-Net");

        assertEquals(1, aggregated.size());
        assertEquals("Guest", aggregated.get(0).ssid);
    }

    @Test
    public void aggregate_filtersEmptySsid() {
        ScanResult empty = scan("", "aa:bb:cc:dd:ee:01", -50);
        ScanResult guest = scan("Guest", "aa:bb:cc:dd:ee:02", -70);

        List<WifiScanResultAggregator.AggregatedEntry> aggregated =
                WifiScanResultAggregator.aggregate(Arrays.asList(empty, guest), null);

        assertEquals(1, aggregated.size());
        assertEquals("Guest", aggregated.get(0).ssid);
    }

    @Test
    public void sortByRssiDesc_ordersStrongestFirst() {
        WifiScanResultAggregator.AggregatedEntry a =
                new WifiScanResultAggregator.AggregatedEntry("A", scan("A", "bssid-a", -50));
        WifiScanResultAggregator.AggregatedEntry b =
                new WifiScanResultAggregator.AggregatedEntry("B", scan("B", "bssid-b", -70));
        WifiScanResultAggregator.AggregatedEntry c =
                new WifiScanResultAggregator.AggregatedEntry("C", scan("C", "bssid-c", -60));

        List<WifiScanResultAggregator.AggregatedEntry> sorted =
                WifiScanResultAggregator.sortByRssiDesc(Arrays.asList(b, c, a));

        assertEquals("A", sorted.get(0).ssid);
        assertEquals("C", sorted.get(1).ssid);
        assertEquals("B", sorted.get(2).ssid);
    }

    @Test
    public void representativeForSsid_prefersBssidThenStrongest() {
        ScanResult weak = scan("Office-Net", "aa:bb:cc:dd:ee:01", -80);
        ScanResult strong = scan("Office-Net", "aa:bb:cc:dd:ee:02", -65);
        List<ScanResult> results = Arrays.asList(weak, strong);

        ScanResult byBssid = WifiScanResultAggregator.representativeForSsid(
                results, "Office-Net", "aa:bb:cc:dd:ee:01");
        assertNotNull(byBssid);
        assertEquals(-80, byBssid.level);

        ScanResult byRssi = WifiScanResultAggregator.representativeForSsid(
                results, "Office-Net", "aa:bb:cc:dd:ee:99");
        assertNotNull(byRssi);
        assertEquals(-65, byRssi.level);
    }

    @Test
    public void aggregate_emptyInputReturnsEmptyList() {
        assertTrue(WifiScanResultAggregator.aggregate(null, null).isEmpty());
        assertTrue(WifiScanResultAggregator.aggregate(Collections.emptyList(), null).isEmpty());
    }

    private static ScanResult scan(String ssid, String bssid, int level) {
        ScanResult result = new ScanResult();
        result.SSID = ssid;
        result.BSSID = bssid;
        result.level = level;
        result.capabilities = "[WPA2-PSK-CCMP]";
        return result;
    }
}
