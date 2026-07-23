## Why

Some customer sites disable router DHCP or require an HTTP proxy for outbound internet access. Today the app connects Wi‑Fi with DHCP only and routes all HTTP/WebSocket traffic directly, so devices can associate to Wi‑Fi without obtaining a usable IPv4 address, and cannot reach cloud APIs behind a corporate proxy. This blocks onboarding, WebSocket connectivity, and OTA in those environments.

## What Changes

- Add **Wi‑Fi static IPv4 configuration** (DHCP or STATIC with IP, mask/prefix, gateway, DNS) as part of the **join flow before connect**, including open networks that currently connect without a dialog.
- Extend **Wi‑Fi details** with IP mode display and an **Edit IP Configuration** primary action styled like the existing **Forget This Network** button (`FrostButtonView` variant `primary`).
- Introduce **WifiConnectionCoordinator** and related profile/store/validator/applier layers; extend privileged `WifiManager` connect to apply STATIC or DHCP per saved profile (keyed by SSID + security type).
- Refine Wi‑Fi link state reporting to distinguish associated-without-IP, L3-ready, and internet-ready (including proxy path).
- Add **CameraRoutePolicy** so eth0 camera routes use `/24` or `/32` when wlan0 overlaps the camera LAN; react to `onLinkPropertiesChanged`.
- Converge outbound HTTP clients through **NetworkHttpClientProvider**, then add **HTTP proxy settings** (enable, host, port, optional Basic auth, test connection) with client-generation invalidation and WebSocket reconnect.
- Add **HTTP Proxy** entry in **Common Settings → Network** (alongside Wireless Network), opening a dedicated settings page.
- Migrate OTA package download from `HttpURLConnection` to OkHttp via the provider so proxy applies consistently.

## Capabilities

### New Capabilities

- `wlan-static-ip`: Per-network DHCP/STATIC IPv4 profiles, join-time and post-connect editing, validation, privileged apply, and eth0 route-policy coordination when wlan0 addressing changes.
- `http-proxy-settings`: Device-wide HTTP proxy configuration, test connection, unified OkHttp client provider with INTERNET_PROXY_AWARE vs DIRECT_LAN routing, and lifecycle invalidation on settings change.

### Modified Capabilities

- `wifi-password-connect-dialog`: Evolve into a Wi‑Fi join dialog that supports password (encrypted) or open join, advanced IP settings (DHCP/STATIC), and IME Connect submission without a duplicate on-screen Connect button.
- `wifi-network-details`: Add IP mode and DNS fields, **Edit IP Configuration** primary button (same styling as Forget), and clear saved IP profile on forget.
- `settings-page-structure`: Common Settings Network group adds an HTTP Proxy row entry.
- `system-wifi-privileged-control`: Connect/update network applies saved DHCP or STATIC `WifiConfiguration` via coordinator; open networks use join dialog instead of silent connect when IP settings are needed.
- `wifi-initialization-onboarding`: Treat associated-but-no-IP as a distinct onboarding/network state; do not treat as fully connected for cloud prerequisites.
- `device-api-origin-selection`: Origin probe uses INTERNET_PROXY_AWARE client from the provider (respects proxy when enabled).
- `device-websocket-connectivity`: WebSocket client from provider; reconnect after proxy settings change.

## Impact

- **UI**: `WifiActivity`, `FrostWifiPasswordDialog` (→ join dialog), `WifiDetailsActivity`, `activity_wifi_details.xml`, `CommonSettingsFragment`, `fragment_common_settings.xml`, new `HttpProxySettingsActivity` (or equivalent).
- **Network core**: new `common/network/wifi/*`, `common/network/proxy/*`, `CameraRoutePolicy`, `CameraEth0Configurator`, `CameraEth0WifiNetworkCallback`.
- **HTTP stack**: `OkHttpConfig`, `RetrofitClient`, `DeviceApiOriginProber`, `DeviceWebSocketConnectionManager`, `OtaUpdateManifestService`, `UpgradeActivity`, `DeviceWorkerAiReportClient`, `DeviceR2StsS3Client`, `DeviceWorkerUsersClient`.
- **Docs reference**: [`docs/wlan-static-ip-and-http-proxy-design.md`](../../../docs/wlan-static-ip-and-http-proxy-design.md), [`docs/camera-eth0-topology.md`](../../../docs/camera-eth0-topology.md).
- **Not in scope**: SOCKS5/PAC proxy, user-configurable eth0, YNHAPI `setStaticIp` for wlan0 until vendor confirms.
