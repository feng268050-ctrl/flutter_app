## Context

LWS runs as a privileged system app on Innohi tablets. Wi‑Fi connect today flows through `WifiActivity` → `FrostWifiPasswordDialog` → `SystemWifiManagerUtils.connectOrUpdateNetwork(ssid, password)` with implicit DHCP. Open networks skip the dialog and connect immediately. `WifiDetailsActivity` is read-only plus **Forget This Network** (`FrostButtonView` `frostedGlassButtonVariant="primary"`, 163×58dp, centered below the card).

Outbound HTTP is fragmented across multiple `OkHttpClient` instances and one `HttpURLConnection` OTA path. eth0 camera addressing is automatic per [`docs/camera-eth0-topology.md`](../../../docs/camera-eth0-topology.md); wlan0 static IP can overlap the camera `/24`, requiring dynamic route policy.

Full architecture reference: [`docs/wlan-static-ip-and-http-proxy-design.md`](../../../docs/wlan-static-ip-and-http-proxy-design.md).

## Goals / Non-Goals

**Goals:**

- Let users configure DHCP or STATIC IPv4 **before** connecting (join dialog) and edit after connect (details page).
- Persist per-network profiles keyed by **SSID + security type**; apply via `WifiConnectionCoordinator` + `WifiIpConfigApplier`.
- Distinguish ASSOCIATED / L3_READY / INTERNET_READY for UI and onboarding.
- Keep camera eth0 working with `CameraRoutePolicy` (`/24` vs `/32`) on wlan0 address changes.
- Unify outbound HTTP through `NetworkHttpClientProvider`; support HTTP proxy (Basic auth, test connection, client generation invalidation).
- Place entry actions as **primary `FrostButtonView` buttons** matching `btn_forget` styling.

**Non-Goals:**

- SOCKS5, PAC, NTLM/Kerberos proxy.
- User-configurable eth0 or YNHAPI `setStaticIp` for wlan0 (until vendor confirms).
- System-wide `Settings.Global.HTTP_PROXY`.

## Decisions

### 1. Join dialog is the primary STATIC IP entry (not details-only)

**Choice:** Extend `FrostWifiPasswordDialog` into `FrostWifiJoinDialog` with **Advanced → IP Settings** (DHCP / STATIC fields). Open networks also open this dialog (password section hidden) instead of silent `connectAndSaveWifi`.

**Rationale:** Without DHCP, association succeeds but IP stays 0; user never reaches `WifiDetailsActivity`.

**Alternative rejected:** Details-only edit — deadlocks on no-DHCP sites.

### 2. Details page: Edit IP Configuration as primary button beside Forget

**Choice:** Add `btn_edit_ip` below the Frost card, stacked with `btn_forget`. Both use `FrostButtonView` `variant="primary"`, same dimensions and horizontal centering as `activity_wifi_details.xml` `btn_forget`. If two buttons, use vertical stack with consistent spacing (e.g. Edit above Forget, or side-by-side only if layout permits at 1280×800).

**Rationale:** User explicitly requested primary-button entry matching forget-network pattern.

### 3. Coordinator layer splits connect concerns

**Choice:** `WifiConnectionCoordinator` orchestrates `WifiNetworkProfileStore`, `WifiIpConfigValidator`, `WifiIpConfigApplier`, and `SystemWifiManagerUtils.connectOrUpdateNetwork(WifiConnectRequest)`.

**Rationale:** Avoid bloating `SystemWifiManagerUtils`; isolate `@hide` `StaticIpConfiguration` in `WifiIpConfigApplier`.

### 4. Profile key = SSID + securityType; internal prefix length

**Choice:** Store `prefixLength` (int); UI may accept dotted mask, convert on save. Key profiles by SSID + security type string derived from scan capabilities.

**Rationale:** Avoid wrong static IP on duplicate SSIDs; BSSID drifts across APs.

### 5. DHCP → STATIC cleanup is explicit

**Choice:** `WifiIpConfigApplier.applyDhcp` sets `IpAssignment.DHCP` and clears `StaticIpConfiguration`.

**Rationale:** Prevents stale static config when switching modes.

### 6. Camera route policy on LinkProperties change

**Choice:** Add `CameraRoutePolicy` enum; `CameraEth0WifiNetworkCallback.onLinkPropertiesChanged` recomputes overlap and applies `/24` or `/32` route via `CameraEth0Configurator`.

**Rationale:** wlan0 on `192.168.1.x` with `/24` on eth0 hijacks customer LAN traffic.

### 7. NetworkHttpClientProvider before proxy injection

**Choice:** Phase 2 migrates all internet clients to `getClient(purpose, routePolicy, boundNetwork)`; Phase 3 adds `HttpProxySettings` to INTERNET_PROXY_AWARE builders only. DIRECT_LAN for camera/localhost.

**Rationale:** Single place for proxy; prevents missed clients.

### 8. Client generation on proxy save

**Choice:** Increment generation on save; `invalidate()` rebuilds clients; `DeviceWebSocketConnectionManager.connectOrReconnect("proxy_settings_changed")`.

**Rationale:** Avoid stale connections and manual nulling of static clients.

### 9. HTTP Proxy entry in Common Settings → Network

**Choice:** Add row in `fragment_common_settings.xml` network group (next to Wireless Network), not legacy `NetworkSettingFragment`.

**Rationale:** Matches live settings structure (`DeviceSettingActivity` tabs).

### 10. IME for STATIC fields

**Choice:** IP/gateway/DNS use `ImeFieldType.SignedDecimal` or dedicated IPv4 field type if added; mask may use numeric pad. Join dialog Connect still via IME Enter (no duplicate on-screen Connect).

**Rationale:** Consistent with existing Wi‑Fi password dialog and IME baseline.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| `@hide` StaticIpConfiguration API drift | Centralize in `WifiIpConfigApplier`; test on target firmware |
| Join dialog complexity | Advanced section collapsed by default; DHCP default |
| Two primary buttons on details | Vertical stack; Edit uses same Frost primary variant |
| Open Wi‑Fi extra tap | Acceptable vs broken no-DHCP open networks |
| Provider migration regressions | Phase 2 before proxy; parity tests per client |
| Proxy breaks camera if mis-routed | `DIRECT_LAN` policy enforced in provider |
| eth0 overlap mis-detected | Unit tests for `CameraRoutePolicy`; field Case A/B in test plan |

## Migration Plan

1. **Phase 0:** `WifiAssociationSnapshot` / `WifiLinkSnapshot`; update `WifiStatusUtils` consumers.
2. **Phase 1:** Wi‑Fi static IP stack + join/details UI + camera route policy.
3. **Phase 2:** `NetworkHttpClientProvider`; migrate clients (no proxy yet).
4. **Phase 3:** Proxy settings UI + generation + WebSocket reconnect.

Rollback: feature flags or revert commits per phase; profiles stored in app-private prefs (safe to leave orphaned).

## Open Questions

- Confirm Innohi firmware Android API level for `StaticIpConfiguration` reflection path.
- Whether Edit + Forget buttons should be horizontal pair or vertical stack on 1280×800 (default: vertical, Edit above Forget).
- EncryptedSharedPreferences for proxy password in v1 or follow-up.
