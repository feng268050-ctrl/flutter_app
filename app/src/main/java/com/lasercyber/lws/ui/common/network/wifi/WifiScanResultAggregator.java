package com.lasercyber.lws.ui.common.network.wifi;

import android.net.wifi.ScanResult;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Collapses Wi-Fi scan results to one representative {@link ScanResult} per SSID (strongest RSSI).
 * Display-only aggregation; connect/profile keys remain SSID + security type.
 */
public final class WifiScanResultAggregator {

    private static final String UNKNOWN_SSID = "<unknown ssid>";

    public static final class AggregatedEntry {
        @NonNull
        public final String ssid;
        @NonNull
        public final ScanResult representative;

        AggregatedEntry(@NonNull String ssid, @NonNull ScanResult representative) {
            this.ssid = ssid;
            this.representative = representative;
        }
    }

    private WifiScanResultAggregator() {
    }

    @Nullable
    public static String normalizeSsid(@Nullable String raw) {
        if (raw == null) {
            return null;
        }
        String ssid = raw.replace("\"", "");
        if (ssid.isEmpty() || UNKNOWN_SSID.equals(ssid)) {
            return null;
        }
        return ssid;
    }

    @NonNull
    public static List<AggregatedEntry> aggregate(
            @Nullable List<ScanResult> scanResults,
            @Nullable String connectedSsidNormalized) {
        if (scanResults == null || scanResults.isEmpty()) {
            return new ArrayList<>();
        }
        String connectedSsid = normalizeSsid(connectedSsidNormalized);
        Map<String, ScanResult> bestBySsid = new LinkedHashMap<>();
        for (ScanResult result : scanResults) {
            if (result == null) {
                continue;
            }
            String ssid = normalizeSsid(result.SSID);
            if (ssid == null) {
                continue;
            }
            if (connectedSsid != null && connectedSsid.equals(ssid)) {
                continue;
            }
            ScanResult existing = bestBySsid.get(ssid);
            if (existing == null || result.level > existing.level) {
                bestBySsid.put(ssid, result);
            }
        }
        List<AggregatedEntry> entries = new ArrayList<>(bestBySsid.size());
        for (Map.Entry<String, ScanResult> entry : bestBySsid.entrySet()) {
            entries.add(new AggregatedEntry(entry.getKey(), entry.getValue()));
        }
        return sortByRssiDesc(entries);
    }

    @NonNull
    public static List<AggregatedEntry> sortByRssiDesc(@NonNull List<AggregatedEntry> entries) {
        List<AggregatedEntry> sorted = new ArrayList<>(entries);
        sorted.sort((left, right) -> Integer.compare(
                right.representative.level,
                left.representative.level));
        return sorted;
    }

  /**
   * Resolves scan-backed metadata for a connected network: prefer {@code preferredBssid}, else
   * strongest RSSI for {@code ssidNormalized}.
   */
    @Nullable
    public static ScanResult representativeForSsid(
            @Nullable List<ScanResult> scanResults,
            @NonNull String ssidNormalized,
            @Nullable String preferredBssid) {
        if (scanResults == null || scanResults.isEmpty()) {
            return null;
        }
        String targetSsid = normalizeSsid(ssidNormalized);
        if (targetSsid == null) {
            return null;
        }
        if (!TextUtils.isEmpty(preferredBssid)) {
            for (ScanResult result : scanResults) {
                if (result == null) {
                    continue;
                }
                if (preferredBssid.equals(result.BSSID)
                        && targetSsid.equals(normalizeSsid(result.SSID))) {
                    return result;
                }
            }
        }
        ScanResult best = null;
        for (ScanResult result : scanResults) {
            if (result == null) {
                continue;
            }
            if (!targetSsid.equals(normalizeSsid(result.SSID))) {
                continue;
            }
            if (best == null || result.level > best.level) {
                best = result;
            }
        }
        return best;
    }
}
