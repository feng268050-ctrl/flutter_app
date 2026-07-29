## Context

`lws-ui` (Android) exposes a dual surface: **cloud** (Worker origin probe → outbound WebSocket + REST/R2) and **LAN** (NanoHTTPD `:5580`, mDNS `_lws-device._tcp`, MediaMTX RTSP, optional camera HTTP proxy). `lws_hmi` already has Wi‑Fi/ethernet, system HTTP proxy (`cyber_hal`), outbound `HttpClientController`, product MediaMTX RTSP relay, local process library / process video SQLite, and Device Information identity QR (`SN|2|Model|SystemVersion`). Missing are the product cloud clients, `:5580` API, mDNS advertise, WS command handlers, and registration/lock UX.

Constraints:

- App owns business HTTP/WS/local server; HAL stays portable (network/proxy/identity only).
- Do not init WebSocket / heavy network servers in `main()` before first frame.
- Process-library cloud import MUST use the shared importer (no Android “delete defaults then duplicate” semantics).
- Cloud env tier entry matches lws-ui: **5×-tap Device SN** (hidden), not a permanent Settings row.
- Product OTA is **out of scope** (separate plan); ignore/no-op OTA WS types.
- Source contracts: sibling `lws-ui` `docs/network-api-reference.md`, `docs/mobile-device-discovery-integration.md`, and archived OpenSpec specs there.

## Goals / Non-Goals

**Goals:**

- Parity with lws-ui **non‑OTA** cloud + LAN behaviors needed for mobile discovery, device registration, remote snapshot/lock, process/video remote ops, and Worker uploads.
- Reuse existing proxy-aware HTTP, SN from HAL/`product.ini`, MediaMTX RTSP, local SQLite backends.
- Spec + phased App modules so implementation can land in slices without blocking unrelated P4 work.

**Non-Goals:**

- Product/firmware/APK OTA UI, manifests, `command.check_update` / `command.update_system`, `device.update_progress`.
- MQTT (removed in lws-ui).
- End-user account login on the HMI.
- Cloud NTP policy UI.
- Full AI Vision cloud productization beyond the Worker AI-report client hook if the AI tab remains stubbed.
- Changing A/B staged upgrade host tooling (`make upgrade`).

## Decisions

### D1 — App module layout (not HAL)

- **Decision:** Place cloud/LAN under `app/lws_hmi/lib/` (e.g. `platform/cloud/`, `platform/local_http/`, `features/device_registration/`), depending on `HttpClientController`, `ProductInfo`, process-library/video repositories, and CyberUI dialogs.
- **Why:** Matches archived HAL design (business HTTP stays in App). Avoids baking Worker URLs into `cyber_hal`.
- **Alternatives:** HAL “cloud controller” — rejected (product-specific, non-portable).

### D2 — HTTP / WebSocket share proxy-aware stack

- **Decision:** All Worker HTTP and WebSocket MUST honor system proxy via the existing Linux HTTP/proxy path (extend client with WebSocket or a sibling factory that reads the same proxy config). Headers: `App-Version`, `Device-Type: Linux` (or `Flutter-Linux` — pick one constant and document; do not silently send `Android`).
- **Why:** Corporate LAN already configured in Settings → HTTP Proxy.
- **Alternatives:** Separate OkHttp-like stack — rejected (duplicate proxy bugs).

### D3 — API origin selection + env tier via SN 5×-tap

- **Decision:** Probe candidate bases (test/prod Workers + optional staged legacy) concurrently; pin first success in-memory for the process (same semantics as lws-ui). Persist **app environment tier** in `/var/lib/hmi/cloud-settings.json`. Change tier via **Device Information → Device SN 5×-tap** (lws-ui `SecretTapTracker`: 5 taps / 5s window), then show Dev/Test/Prod picker; on change, clear pin and `reprobeAndReconnect`.
- **Why:** Match operator muscle memory from Android; keep the control off the normal Settings surface.
- **Alternatives:** Explicit permanent “Cloud Environment” row — rejected (lws-ui parity).

### D4 — WebSocket command set (OTA no-op)

- **Decision:** Implement unified envelope `v/type/id/ts/payload`. Handle non‑OTA types from lws-ui; for `command.check_update`, `command.update_system`, and outbound `device.update_progress`, **acknowledge with explicit unsupported / no-op** (do not crash, do not start downloads).
- **Why:** Cloud may still send OTA commands; HMI must stay stable until OTA change lands.
- **Alternatives:** Close connection on OTA — too brittle.

### D5 — Local HTTP `:5580` with dart:io HttpServer

- **Decision:** Embed an HTTP server bound to `0.0.0.0:5580` in the App process using **`dart:io` `HttpServer`** (shelf/`shelf_io` is incompatible with Flutter **3.24.4** / `collection` pin via `flutter_localizations`). Bind failure is non-fatal (log + continue). Response envelope `ApiResult` for JSON routes; `GET /lasercyber` plain text. Share query/serialization with WS video/process handlers via one service layer.
- **Why:** Matches lws-ui port contract; App already owns SQLite data; keeps Flutter SDK pin intact.
- **Alternatives:** shelf 1.4.2 — rejected (requires `http_parser`/`collection` newer than Flutter 3.24.4). systemd `lighttpd` + CGI — heavier, harder to share Dart domain logic.

### D6 — mDNS advertise via Avahi, `connect_proto=http`, port `5580`

- **Decision:** Advertise `_lws-device._tcp` with TXT `sn`, `model`, `system_version`, `api_ver=1`, **`connect_proto=http`**, port **`5580`**. Prefer Avahi (already on rootfs) via D-Bus or `avahi-publish-service`, started/stopped with local HTTP health. Document mobile compatibility: older mobile builds expecting `ws`/`9527` may need a mobile follow-up; Linux HMI tells the truth about the working LAN API.
- **Why:** lws-ui advertises `9527`/`ws` but has no local WS listener — known gap. Linux should not repeat a broken contract.
- **Alternatives:** Blind copy `9527`/`ws` — rejected until a real local WS exists. Dual advertise — optional later if mobile requires it.

### D7 — Registration / lock UX

- **Decision:** Keep existing Device Information QR. Bind / registration dialogs are shown from cloud runtime hooks (users probe unbound → bind QR; WS `401` → registration QR). Remote lock store in App prefs; status-bar lock icon; Quick/Engineer entry blocked when locked (`confirmNotLocked`). **Home auto-dialog / wifi-init prompt queue is out of scope for this change** (separate plan). OTA home prompts excluded.
- **Why:** Cloud/LAN parity without inventing login; Home prompt orchestration deferred.
- **Alternatives:** Full HomePromptQueue parity day one — deferred to a dedicated change.

### D8 — Camera LAN surface

- **Decision:** Keep MediaMTX RTSP as primary LAN camera preview (`rtsp://<device-ip>:8554/camera/pr0`). Add camera LAN HTTP reverse proxy (`:9000`) only if product still needs IPC HTTP from Wi‑Fi clients (parity with `CameraLanHttpProxy`); otherwise defer behind an open question once camera topology on Linux is validated.
- **Why:** RTSP path already exists; proxy is secondary.
- **Alternatives:** Full NanoHTTPD camera proxy day one — may be unnecessary if eth0 isolation differs.

### D9 — ADB endpoint → LAN SSH debug mapping

- **Decision:** `POST /v1/adb` either maps to enabling existing **LAN SSH debug** (document as Linux equivalent) or returns `501`/`ApiResult` failure with message that ADB is Android-only. Prefer mapping to SSH debug for mobile remote-assist parity.
- **Why:** Linux board has no Android ADB; SSH debug already productized.
- **Alternatives:** No-op silently — worse for mobile tooling.

### D10 — Phased delivery inside this change

1. Origin probe + cloud HTTP users/R2 scaffolding + registration QR/dialogs  
2. WebSocket connect + online/stat + lock + clear alerts + OTA no-op  
3. Local HTTP `:5580` health + process library + videos (as local backends allow)  
4. mDNS advertise  
5. WS process/video command handlers + R2 upload runners  
6. Monitor/camera SSE and remaining LAN routes  

Each phase must leave the App bootable if cloud is unreachable.

## Risks / Trade-offs

- [Mobile expects `ws`/`9527`] → Mitigation: D6 documents `http`/`5580`; coordinate with `lasercyber-mobile` or temporarily dual-publish if blockers appear.
- [Process-library cloud push semantics differ from Android] → Mitigation: always run shared importer; reject delete-defaults path.
- [Local HTTP + WS duplicate logic drifts] → Mitigation: single query/service layer used by both transports.
- [Proxy + WebSocket edge cases] → Mitigation: reuse one proxy config; add probe/WS integration tests with proxy on/off.
- [Avahi/mDNS blocked by resolved LLMNR/mDNS off] → Mitigation: use Avahi daemon publish, not systemd-resolved mDNS; verify on ynh960 + emulator.
- [OTA commands from cloud confuse operators] → Mitigation: no-op ack + log; no UI that looks like an update started.
- [Large scope slips] → Mitigation: tasks ordered by D10; ship health + registration before full video SSE.

## Migration Plan

1. Land App modules behind feature init after first frame; no rootfs package rebuild required for Dart-only slices (except Avahi publish helpers if new overlay scripts).
2. Validate on emulator (P3.2) for HTTP/WS against test Worker; validate mDNS/`5580` on real LAN with mobile or `dns-sd`/`avahi-browse`.
3. Roll forward with `make build-app` / `make push-app`; overlay changes only if Avahi units/scripts added.
4. Rollback: stop advertising / disable local server via flag or revert App push; cloud clients idle when origin probe fails.

## Open Questions

1. ~~Confirm with mobile team: is `connect_proto=http` + port `5580` acceptable for `api_ver=1`, or is a dual advertise / local WS shim required?~~  
   **Provisional (2026-07-29):** Adopted **`http` / `5580`** on Linux HMI (truthful LAN API). Dual-advertise or local WS shim only if `lasercyber-mobile` cannot consume `connect_proto=http`. Track mobile confirmation as follow-up; do not reintroduce fake `9527`/`ws` without a real listener.
2. Exact `Device-Type` header string for Linux HMI (propose `Linux`) — **adopted: `Linux`**.
3. Is camera HTTP `:9000` proxy still required on eth0-isolated Linux topology? — **Deferred:** RTSP LAN path is primary; `:9000` proxy not implemented in this change.
4. Env-tier UI: Device Information **Device SN 5×-tap** (lws-ui parity); no permanent Cloud Environment row.
5. Minimum viable LAN route set for first mobile acceptance (`/lasercyber` + identity only vs full video/process set)? — **Shipped:** health + videos list/read/delete/stream + process-library list + SSH-debug mapping; monitor/camera SSE return structured 501 until backends land.
