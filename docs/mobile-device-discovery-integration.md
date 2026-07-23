# Mobile App mDNS Discovery & Connection Integration

## 1. Discovery Contract

- `serviceType`: `_lws-device._tcp.` (Android `NsdServiceInfo` uses the trailing dot; many desktop browsers accept `_lws-device._tcp` as the same browse type.)
- `transport`: DNS-SD via mDNS
- `defaultPort`: `9527`

### TXT Fields

| Field | Required | Example | Notes |
| --- | --- | --- | --- |
| `sn` | Yes | `LCYB-2026-0001` | Device serial number, unique identity used across LAN discovery and QR/SN binding |
| `model` | Yes | `LaserCyber L1` | Machine model string; same source as HMI **Settings → Device Information → Machine Model** (ROM `model.properties`, not Android `Build.MODEL` / board name) |
| `system_version` | Yes | `1.0.22` | Installed HMI app `versionName`; same as **Settings → Device Information → System Version** |
| `api_ver` | Yes | `1` | Discovery/connection protocol version |
| `connect_proto` | Yes | `ws` | Supported values: `ws`, `http` |

### Compatibility Matrix

| Mobile `api_ver` | Device `api_ver` | Behavior |
| --- | --- | --- |
| 1 | 1 | Full support |
| 1 | >1 | Attempt backward-compatible connect; if handshake says unsupported, fail with `PROTOCOL_MISMATCH` |
| >1 | 1 | Mobile should downgrade or prompt upgrade path |

## 2. Discovery-to-Connection Sequence

1. Mobile app starts DNS-SD browse for `_lws-device._tcp.`.
2. Mobile app resolves service and parses TXT record.
3. Mobile app validates required fields (`sn`, `model`, `system_version`, `api_ver`, `connect_proto`).
4. Mobile app builds endpoint from resolved host + port + `connect_proto`.
5. Mobile app initiates handshake (timeout `5000ms`, retry up to `3`).
6. On success, mobile app continues existing bind flow using canonical `sn`.

## 3. Connection Error Mapping

| Error Code | Trigger | Mobile UX Suggestion |
| --- | --- | --- |
| `ENDPOINT_UNREACHABLE` | Resolved host/port not reachable | "设备暂不可连接，请确认同一局域网并重试" |
| `HANDSHAKE_TIMEOUT` | No handshake response within timeout | "连接超时，请稍后重试" |
| `PROTOCOL_MISMATCH` | `api_ver`/`connect_proto` unsupported | "设备版本不兼容，请升级 App 或设备" |

## 4. Observability Fields

Discovery telemetry fields:

- `mdns_service_type`
- `mdns_instance_name`
- `mdns_sn`
- `mdns_api_ver`
- `mdns_connect_proto`
- `mdns_parse_result`

Connection telemetry fields:

- `connect_host`
- `connect_port`
- `connect_attempt`
- `connect_result`
- `connect_error_code`
- `handshake_latency_ms`

## 5. Coexistence with Existing QR/SN Binding

- LAN discovery is additive; do not remove or alter QR-code/SN entry points.
- `sn` from discovery must map to the same canonical record as QR/SN-based binding.
- If both entries target the same physical device, backend must converge to one device identity and state.

## Troubleshooting (HMI not visible on LAN)

- HMI mDNS is tied to **Wi-Fi link up**, not to cloud/API reachability. If older builds only advertised after HTTP probe success, upgrade to a build that uses a Wi-Fi-only `NetworkCallback`.
- Phone/laptop must be on the **same L2 broadcast domain** as the HMI (no AP/client isolation; not only on cellular).
- In Discovery tools, browse **`_lws-device._tcp`** or **`_lws-device._tcp.`** explicitly (not only `_http._tcp`).
- **Android 11 (API 30)**: The app uses the portable **`registerService(NsdServiceInfo, int, RegistrationListener)`** only (no per-`Network` bind in our codebase). Announcements follow the **process default route**. If **mobile data is active** and wins as default, some devices may not expose mDNS on the Wi‑Fi LAN — test with cellular off or Wi‑Fi-only routing. **MulticastLock** + `CHANGE_WIFI_MULTICAST_STATE` still matters on API 30.

## 6. Joint Acceptance Checklist

- [ ] HMI advertises `_lws-device._tcp.` only when local connection service is healthy.
- [ ] TXT required fields are complete and parseable on mobile app.
- [ ] Network switch (Wi-Fi reconnect/IP change) triggers re-publish and mobile can rediscover device.
- [ ] Mobile can connect through discovered endpoint in happy path.
- [ ] Error paths produce mapped codes and expected user-visible messages.
- [ ] Discovery and connection telemetry fields are emitted as documented.
- [ ] Identity convergence verified between LAN discovery and QR/SN entries.
