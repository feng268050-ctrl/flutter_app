## Why

`lws-ui` already ships cloud Worker connectivity (API origin probe, device WebSocket, R2/HTTP clients) and a LAN surface (HTTP `:5580`, mDNS, camera relay) that mobile and remote tooling depend on. `lws_hmi` has networking foundations (Wi‑Fi, system proxy, outbound HTTP client, MediaMTX RTSP) but still lacks that product cloud/LAN business layer, so Linux devices cannot register, sync, or be discovered the same way. P4 calls out 云服务 / `:5580`; this change ports the non‑OTA slice now so mobile/cloud parity can land before a separate OTA plan.

## What Changes

- Add **API origin selection**: probe candidate Worker bases (dev/test/prod), pin the first reachable origin for product HTTP + WebSocket (reuse system HTTP proxy).
- Add **device WebSocket client** to `wss://{pinned}/ws/device?sn=…` with unified envelope, reconnect/backoff, `device.online` / `command.stat_*`, and non‑OTA command handlers (process param/library, video list/upload/delete, remote lock, clear alerts, forced disconnect).
- Add **Worker HTTP clients** for device users (binding probe), R2 STS + object upload, process-video metadata registration, and AI report upload (when local AI/video surfaces exist).
- Add **LAN HTTP server** on `0.0.0.0:5580` aligned with lws-ui (`/lasercyber`, videos, process-library, monitor SSE, camera control routes that already have App backends).
- Add **mDNS / DNS‑SD advertisement** for `_lws-device._tcp` so LaserCyber mobile can discover the device on LAN (resolve advertised port vs working HTTP `:5580` during design).
- Add **device registration / binding UX**: identity QR on Device Information, bind/registration dialogs on unbound SN or WS `401` (no end-user login on HMI).
- Add **remote lock** store + status-bar / home prompt parity with lws-ui.
- Wire **lazy post–first-frame** startup (network available → probe → WS; local HTTP + mDNS from app scope) without blocking boot UI.
- **Explicitly out of scope (separate plan):** product/APK/firmware OTA, `command.check_update` / `command.update_system`, `device.update_progress`, auto-check OTA UI, bundled firmware upgrade, MediaMTX-from-OTA installer, cloud NTP policy UI.

## Capabilities

### New Capabilities

- `device-api-origin-selection`: Probe and pin Worker API base URL; app environment tier; map to WS URL scheme/path.
- `device-cloud-websocket`: Outbound device WebSocket lifecycle, unified envelope, non‑OTA command dispatch, online/stat snapshot, forced-disconnect suppression.
- `device-cloud-http`: Worker REST clients (users binding, R2 STS/upload, video metadata, AI report) over proxy-aware HTTP.
- `device-local-http-api`: Embedded LAN HTTP API on `:5580` (health, videos, process library, monitor/camera routes as backends allow).
- `device-mdns-advertise`: DNS‑SD `_lws-device._tcp` advertisement with SN/model/version TXT for mobile discovery.
- `device-registration-ui`: Device identity QR, bind/registration dialogs, remote-lock UX hooks (status bar / home prompt).

### Modified Capabilities

- `linux-http-client`: Product cloud traffic SHALL use the existing proxy-aware client path (purpose/route policy), not a parallel unmanaged stack.
- `settings-ui`: Device Information gains identity QR / env-tier affordance; Common Settings remains network/proxy only (no separate “cloud settings” screen).
- `app-page-status-bar`: Show remote-lock indicator when locked.
- `ip-camera`: LAN camera HTTP proxy / RTSP advertise alignment with local HTTP + MediaMTX where still missing vs lws-ui (no OTA MediaMTX install).

## Impact

- **App (`app/lws_hmi/`):** new cloud/LAN modules under platform or features (HTTP server, WS manager, origin prober, command handlers, registration UI); settings Device Information + status bar; l10n from lws-ui string resources (not mobile cloud ARBs).
- **HAL (`packages/cyber_hal/`):** prefer App-owned business clients; HAL may only gain thin helpers if needed (e.g. mDNS publish wrapper). Do **not** put Worker/WS/business HTTP in portable HAL.
- **Rootfs / Buildroot:** may need Avahi (or equivalent) publish path if not usable today; firewall/ports `:5580` (and advertised discovery port); keep MediaMTX as existing RTSP relay.
- **Identity:** device SN via `product.ini` / HAL `ProductInfo` (same binding model as lws-ui).
- **Dependencies:** Dart WebSocket + HTTP (existing), embedded HTTP server package, mDNS/Avahi integration, S3-compatible client for R2 (or minimal SigV4 PutObject).
- **Contracts:** align behavior with lws-ui `docs/network-api-reference.md` and sibling OpenSpec specs; OTA message types ignored/unimplemented until a later change.
- **Related deferred work:** process-library “阶段 F” cloud import semantics, full process-video cloud upload UX, and all OTA remain separate slices even if WS/HTTP scaffolding lands here.
