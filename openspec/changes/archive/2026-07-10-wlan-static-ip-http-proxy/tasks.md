## 1. Phase 0 — Wi‑Fi link state model

- [x] 1.1 Add `WifiAssociationSnapshot` and `WifiLinkSnapshot` under `common/network/wifi/`
- [x] 1.2 Extend `WifiStatusUtils` to populate snapshots and expose ASSOCIATED vs L3_READY helpers
- [x] 1.3 Update `wifi-initialization-onboarding` consumers to use usable L3 connection (not association-only)
- [x] 1.4 Add unit tests for snapshot parsing and associated-without-IP detection

## 2. Phase 1 — Wi‑Fi static IP core

- [x] 2.1 Add `WifiIpConfig`, `WifiNetworkProfile`, `WifiConnectRequest` data classes
- [x] 2.2 Implement `WifiNetworkProfileStore` (SSID + securityType key, SharedPreferences/DataStore)
- [x] 2.3 Implement `WifiIpConfigValidator` (IPv4, prefix, gateway, DNS, camera/eth0 conflict)
- [x] 2.4 Implement `WifiIpConfigApplier` with DHCP/STATIC apply and static clear on DHCP switch
- [x] 2.5 Refactor `SystemWifiManagerUtils.connectOrUpdateNetwork(WifiConnectRequest)` to reuse existing `WifiConfiguration`
- [x] 2.6 Implement `WifiConnectionCoordinator.connect` orchestration and error mapping
- [x] 2.7 Add unit tests for validator, mask→prefix conversion, and profile store round-trip

## 3. Phase 1 — Camera route policy

- [x] 3.1 Add `CameraRoutePolicy` enum and overlap detection helper
- [x] 3.2 Extend `CameraEth0Configurator` to apply `/24` or `/32` per policy
- [x] 3.3 Add `onLinkPropertiesChanged` to `CameraEth0WifiNetworkCallback` and trigger reconfigure
- [x] 3.4 Add unit tests for overlap Case A (subnet route) and Case B (host route)

## 4. Phase 1 — Join dialog UI (primary entry for STATIC)

- [x] 4.1 Create `dialog_frost_body_wifi_join.xml` with password (optional), Advanced IP Settings (DHCP/STATIC fields)
- [x] 4.2 Evolve `FrostWifiPasswordDialog` → `FrostWifiJoinDialog` (open network hides password; IME Connect submits)
- [x] 4.3 Wire `WifiActivity.onWifiItemClick` so encrypted and open networks both open join dialog
- [x] 4.4 Connect join dialog submit to `WifiConnectionCoordinator` with security type from scan
- [x] 4.5 Add string resources for IP mode, Advanced, STATIC field labels (en/zh)

## 5. Phase 1 — Wi‑Fi details UI (Edit IP primary button)

- [x] 5.1 Add IP mode, DNS1, DNS2 rows to `activity_wifi_details.xml` (LinkProperties display)
- [x] 5.2 Add `btn_edit_ip` `FrostButtonView` primary (match `btn_forget` size/variant); stack Edit above Forget
- [x] 5.3 Implement edit flow (dialog or activity) bound to `WifiNetworkProfile`; save + reconnect
- [x] 5.4 Clear stored profile on forget in `WifiDetailsActivity`
- [x] 5.5 Verify frosted confirm dialogs for destructive actions still use `FrostDialog.prompt`

## 6. Phase 2 — NetworkHttpClientProvider (no proxy yet)

- [x] 6.1 Add `NetworkRoutePolicy`, `ClientPurpose`, `NetworkHttpClientProvider` skeleton with DIRECT_LAN and INTERNET paths
- [x] 6.2 Migrate `OkHttpConfig` / `RetrofitClient` to provider (`API`, INTERNET_PROXY_AWARE)
- [x] 6.3 Migrate `DeviceWebSocketConnectionManager.wsClient` (`WEBSOCKET`)
- [x] 6.4 Migrate `DeviceApiOriginProber` (`PROBE`, optional bound wlan Network)
- [x] 6.5 Migrate `OtaUpdateManifestService`, `DeviceWorkerAiReportClient`, `DeviceR2StsS3Client`, `DeviceWorkerUsersClient`
- [x] 6.6 Replace `UpgradeActivity` OTA download `HttpURLConnection` with OkHttp streaming via provider (`OTA_DOWNLOAD`)
- [x] 6.7 Ensure camera/local HTTP call sites use `DIRECT_LAN` only

## 7. Phase 3 — HTTP proxy settings

- [x] 7.1 Add `HttpProxySettings`, `ProxyAuthType`, `HttpProxySettingsStore`
- [x] 7.2 Inject proxy + Basic authenticator into INTERNET_PROXY_AWARE client builder
- [x] 7.3 Implement client generation counter and `invalidate()`; wire `RetrofitClient` reset
- [x] 7.4 Reconnect WebSocket on proxy save (`proxy_settings_changed`)
- [x] 7.5 Add HTTP Proxy row to `fragment_common_settings.xml` Network group
- [x] 7.6 Create `HttpProxySettingsActivity` (enable, host, port, auth, Test Connection + Save as `FrostButtonView` primary)
- [x] 7.7 Implement Test Connection against pinned/candidate API origin through proxy
- [x] 7.8 Add unit tests for provider proxy on/off and generation bump

## 8. Verification

- [x] 8.1 Manual: DHCP network — connect behavior unchanged
- [x] 8.2 Manual: router DHCP OFF — STATIC via join dialog → L3_READY → API reachable
- [x] 8.3 Manual: open Wi‑Fi + STATIC before connect
- [x] 8.4 Manual: Edit IP on details page (primary button) → save → reconnect
- [x] 8.5 Manual: eth0 Case A and Case B camera RTSP/HTTP after wlan0 STATIC
- [x] 8.6 Manual: HTTP proxy ON — API, WSS, OTA manifest/download, upload; camera/localhost direct
- [x] 8.7 Run `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync` after UI changes
