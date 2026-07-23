## 1. Shared Wi-Fi reader

- [x] 1.1 Add `ConnectedWifiInfo` DTO with Gson-friendly camelCase fields (`ssid`, `bssid`, `capabilities`, `ipAddress`, `subnetMask`, `router`, `dns`, `rssi`, `linkSpeed`, `frequency`, `securityType`, `macAddress`)
- [x] 1.2 Implement `WifiStatusUtils.getConnectedWifiInfo(Context)` by extracting logic from `WifiDetailsActivity` (DHCP, link-properties subnet fallback, scan capabilities, security label, MAC masking rules)
- [x] 1.3 Refactor `WifiDetailsActivity.renderWifiDetails()` to call the shared reader and map results to UI rows (preserve existing display/fallback behavior)

## 2. Remote snapshot wire format

- [x] 2.1 Replace `DeviceRemoteSnapshot.localIP` with `wifiInfo` (`ConnectedWifiInfo`)
- [x] 2.2 Set `wifiInfo` in `DeviceStatusPut.packRemoteSnapshot` via `WifiStatusUtils.getConnectedWifiInfo`
- [x] 2.3 Remove `getConnectedWifiIpAddress` from public snapshot path (keep or inline only as helper inside reader)

## 3. Tests and documentation

- [x] 3.1 Update `DeviceRemoteSnapshotTest`: assert `wifiInfo` serializes expected fields; assert JSON does not contain `localIP`
- [x] 3.2 Add unit tests for `getConnectedWifiInfo` / security derivation where testable without full framework mocks
- [x] 3.3 Update `docs/network-api-reference.md`: document `wifiInfo` schema and **BREAKING** removal of `localIP`

## 4. Verification

- [x] 4.1 Manual: connected Wi-Fi → open details screen → trigger `command.stat_request` → confirm `wifiInfo` fields match on-screen rows
- [x] 4.2 Manual: disconnected Wi-Fi → `wifiInfo` is `null` in `stat_response` and `device.online`
