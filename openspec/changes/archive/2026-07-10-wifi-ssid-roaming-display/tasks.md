## 1. Aggregator utility

- [x] 1.1 Add `WifiScanResultAggregator` with `normalizeSsid`, `aggregate(scanResults, connectedSsid)`, and `sortByRssiDesc` in `com.lasercyber.lws.ui.common.network.wifi`
- [x] 1.2 Add `WifiScanResultAggregatorTest` covering multi-BSSID same SSID, empty SSID filter, connected SSID exclusion, and sort order

## 2. WifiActivity integration

- [x] 2.1 Replace inline `bestResultBySsid` loop in `WifiActivity.updateWifiList()` with `WifiScanResultAggregator`
- [x] 2.2 Update `findConnectedScanResult()` to fall back to aggregated representative for connected SSID when BSSID match fails
- [x] 2.3 Verify connected row (`wifiCon`) still excludes connected SSID from scanned list below

## 3. Consistency audit

- [x] 3.1 Grep for other `getScanResults()` list builders; align or document why exempt (`WifiStatusUtils.resolveSecurityCapabilitiesFromScan` is lookup-only, not a list UI)
- [x] 3.2 Confirm join/connect path still uses SSID + security type only (no BSSID profile key regression)

## 4. Verification

- [x] 4.1 Run unit tests (`WifiScanResultAggregatorTest`)
- [x] 4.2 Manual RK3566: multi-AP same SSID environment — list shows one row per SSID, RSSI updates after rescan
