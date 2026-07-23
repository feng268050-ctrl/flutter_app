## Why

Remote operators currently receive only a single `localIP` string in the WebSocket remote snapshot (`command.stat_response` / `device.online`). That is insufficient for support and diagnostics—they need the same connection metadata the on-device **Wi-Fi 详情** screen shows (IP, mask, gateway, DNS, signal, link speed, security, frequency, MAC, SSID/BSSID). Replacing `localIP` with a structured `wifiInfo` object aligns the wire format with what operators already see on the device and avoids duplicating IP-only logic on the server.

## What Changes

- **BREAKING**: Remove root-level `localIP` from the remote snapshot JSON (`command.stat_response` `payload.data` and `device.online` `payload`).
- Add root-level object field **`wifiInfo`** containing the full connected Wi-Fi snapshot (or JSON `null` when not connected / unavailable).
- Extract shared read logic from `WifiDetailsActivity` into a reusable utility (same sources: `WifiInfo`, `DhcpInfo`, `LinkProperties`, scan `capabilities` fallback) so the details UI and `DeviceStatusPut.packRemoteSnapshot` stay in sync.
- Update `DeviceRemoteSnapshot`, unit tests, and `docs/network-api-reference.md` to document `wifiInfo` and the removal of `localIP`.

## Capabilities

### New Capabilities

_(none — behavior extends existing remote snapshot and Wi-Fi details capabilities)_

### Modified Capabilities

- `device-remote-snapshot`: Replace `localIP` requirement with `wifiInfo` object requirement (fields mirror Wi-Fi details page data; `null` when no connected Wi-Fi).

## Impact

- **Wire/API**: `command.stat_response`, `device.online` — breaking field rename/removal for consumers of `localIP`.
- **App**: `DeviceRemoteSnapshot`, `DeviceStatusPut`, new or extended `WifiStatusUtils` (or dedicated DTO), `WifiDetailsActivity` refactor to call shared reader, `DeviceRemoteSnapshotTest`, network API docs.
- **Server/backoffice**: Must stop reading `localIP` and adopt `wifiInfo` (coordination outside this repo).
