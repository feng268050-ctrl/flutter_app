## Context

`DeviceStatusPut.packRemoteSnapshot` builds `DeviceRemoteSnapshot` for `command.stat_response` and `device.online`. Today it sets `localIP` via `WifiStatusUtils.getConnectedWifiIpAddress`, which only exposes the IPv4 from `WifiInfo#getIpAddress()`.

`WifiDetailsActivity.renderWifiDetails()` already aggregates richer connection data for the on-device UI:

| UI row | Source |
|--------|--------|
| IP Address | `WifiInfo#getIpAddress()` → `WifiStatusUtils.formatIpAddress` |
| Subnet Mask | `DhcpInfo#netmask`, else `LinkProperties` prefix for matching IPv4 |
| Router | `DhcpInfo#gateway` |
| DNS | `DhcpInfo#dns1` |
| Signal strength | Intent `EXTRA_RSSI` or `WifiInfo#getRssi()` |
| Link speed | Intent / `WifiInfo#getLinkSpeed()` |
| Security type | `capabilities` string → WPA3/WPA2/WPA/WEP/Open |
| Frequency | Intent / `WifiInfo#getFrequency()` |
| MAC | `WifiInfo#getMacAddress()` |

SSID/BSSID come from activity intent extras when opened from the list; for snapshot build they must be read from `WifiInfo` (normalized SSID) and `WifiInfo#getBSSID()`.

## Goals / Non-Goals

**Goals:**

- Replace `localIP` with `wifiInfo` on the remote snapshot root object.
- Populate `wifiInfo` using one shared reader so WebSocket export and Wi-Fi details UI cannot drift.
- Preserve existing IP formatting and DHCP/link-property fallback behavior from `WifiDetailsActivity`.
- Emit JSON `null` for `wifiInfo` when the device is not on a connected Wi-Fi network with usable `WifiInfo` (same bar as today’s `localIP == null`).

**Non-Goals:**

- Changing `command.stat_request` / response envelope shape beyond snapshot fields.
- Exposing privileged actions (forget network) over WebSocket.
- Returning scan lists or nearby APs—only the **currently connected** network.
- Backward-compatible dual emission of `localIP` and `wifiInfo`.

## Decisions

1. **DTO: `ConnectedWifiInfo` (new type in `bean.entity.dto` or adjacent)**  
   Gson-serialized nested object under `wifiInfo` with camelCase JSON fields aligned to the details screen:

   - `ssid`, `bssid`, `capabilities` (raw scan capabilities when known)
   - `ipAddress`, `subnetMask`, `router`, `dns` (dotted-decimal strings; omit or `null` when unavailable—prefer `null` for machine consumers vs UI “not available” placeholder strings)
   - `rssi` (int, dBm), `linkSpeed` (int, Mbps), `frequency` (int, MHz)
   - `securityType` (string: `WPA3` | `WPA2` | `WPA` | `WEP` | `Open`)
   - `macAddress` (string; `null` when masked/unavailable)

   **Rationale:** Structured, self-describing for servers; mirrors operator-visible fields.  
   **Alternative:** Flatten with prefixed keys on snapshot root — rejected (pollutes snapshot, harder to version).

2. **Shared reader: `WifiStatusUtils.getConnectedWifiInfo(Context)`**  
   Move subnet/gateway/DNS/security resolution out of `WifiDetailsActivity` into `WifiStatusUtils` (or a small `ConnectedWifiInfoReader` used by both). `WifiDetailsActivity` formats values for display; snapshot uses the same numeric sources then formats IPs via existing `formatIpAddress`.

   **Rationale:** User asked to reuse the details-page data path; single module avoids copy-paste of `resolveSubnetMaskFromLinkProperties` and `resolveSecurityCapabilitiesFromScan`.

3. **Connectedness gate**  
   Set `wifiInfo` to non-null only when `WifiStatusUtils.isWifiConnected(context)` is true **and** `WifiInfo` has a non-empty normalized SSID (not `<unknown ssid>`) **and** non-zero `getIpAddress()` (consistent with list “connected” row and prior `localIP` semantics).

   **Rationale:** Avoid partial objects during connecting state; matches prior null `localIP` when no LAN IP.

4. **Remove `localIP` field entirely**  
   **BREAKING** for any consumer; document in API reference and delta spec with migration note to `wifiInfo.ipAddress`.

5. **Keep `getConnectedWifiIpAddress` internally**  
   May remain as helper used by `getConnectedWifiInfo` or be inlined; no longer exposed on snapshot.

## Risks / Trade-offs

- **[Risk] Breaking server parsers expecting `localIP`** → Document in `docs/network-api-reference.md`; coordinate backend deploy order (read `wifiInfo.ipAddress` after upgrade).
- **[Risk] UI placeholder vs JSON null** → Snapshot MUST use `null` for missing scalars, not `R.string.wifi_not_available` text.
- **[Risk] MAC privacy / `02:00:00:00:00:00`** → Same as details page: emit `null` when MAC is empty or randomized.
- **[Risk] Refactor regression on details screen** → Manual smoke: open Wi-Fi details while connected; compare rows to a captured `stat_response` JSON.

## Migration Plan

1. Ship app with `wifiInfo` only (no `localIP`).
2. Update server/backoffice to read `wifiInfo`; remove `localIP` handling.
3. No on-device migration of persisted data (snapshot is ephemeral per message).

## Open Questions

- None blocking implementation; confirm with backend that `wifiInfo` root `null` (entire object absent vs null) matches Gson `serializeNulls` behavior used elsewhere on the snapshot.
