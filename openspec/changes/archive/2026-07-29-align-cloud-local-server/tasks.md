## 1. Foundations

- [x] 1.1 Add App module scaffolding (`platform/cloud/`, `platform/local_http/`, registration feature) and wire lazy post–first-frame init in `app_services` / bootstrap
- [x] 1.2 Persist app environment tier (`cloud-settings.json`); change via Device SN 5×-tap (lws-ui `SecretTapTracker`)
- [x] 1.3 Extend HTTP stack: shared headers (`App-Version`, Linux `Device-Type`), WebSocket factory that reads the same proxy config as `HttpClientController`
- [x] 1.4 Implement API origin prober + in-memory pin; unit tests for URL mapping (`http`/`https` → `ws`/`wss`, SN query)

## 2. Cloud HTTP clients

- [x] 2.1 Implement `GET /v1/devices/:sn/users` binding probe against pinned origin
- [x] 2.2 Implement R2 STS client + S3-compatible PutObject helper (no secrets in info logs)
- [x] 2.3 Implement process-video metadata registration client (lws-ui route parity)
- [x] 2.4 Add AI report multipart client (callable even if AI UI remains stub)

## 3. Device WebSocket (non-OTA)

- [x] 3.1 Implement WebSocket connection manager (connect/reconnect/backoff, forced-disconnect suppression, auth-error latch)
- [x] 3.2 Implement unified envelope codec + dispatcher; OTA types (`check_update` / `update_system` / `update_progress`) as safe no-ops
- [x] 3.3 Build remote snapshot packer from available Linux App/HAL sources; send `device.online` and handle `command.stat_request`
- [x] 3.4 Implement remote lock store + `command.lock` / `command.unlock` / `command.clear_alerts` / `command.disconnect`
- [x] 3.5 Implement process-param / process-library WS handlers via shared importer/repository (no Android delete-defaults semantics)
- [x] 3.6 Implement video list / upload-trigger / delete WS handlers sharing services with LAN HTTP

## 4. Registration and operator UX

- [x] 4.1 Bind prompt when users probe is empty; registration dialog on WS `401` (QR v2, Cancel / Reconnect, no stacked dialogs)
- [x] 4.2 Add remote-lock status-bar indicator + home/mode entry blocking per policy
- [x] 4.3 Add l10n strings from lws-ui resources (EN/zh) for registration/lock copy; `flutter analyze` on touched App code

## 5. Local HTTP `:5580`

- [x] 5.1 Embed shelf (or equivalent) server on `0.0.0.0:5580`; non-fatal bind failure; lifecycle with App
- [x] 5.2 Implement `GET /lasercyber` and `ApiResult` helper
- [x] 5.3 Wire `/v1/videos` list/read/stream/delete/upload to local process-video backend (as available) — **errata:** upload/`videoId`/filters completed 2026-07-30; see [errata.md](errata.md)
- [x] 5.4 Wire `/v1/process-library` and `/v1/process-parameters/*` to shared process-library backend
- [x] 5.5 Add monitor/camera routes or structured not-implemented responses; map `POST /v1/adb` to LAN SSH debug — **errata:** SSE/camera/adb `data:null` completed 2026-07-30; see [errata.md](errata.md)
- [x] 5.6 Host/integration smoke: curl health + one JSON route on emulator or board

## 6. mDNS and camera LAN

- [x] 6.1 Publish `_lws-device._tcp` via Avahi with TXT (`sn`, `model`, `system_version`, `api_ver=1`, `connect_proto=http`) on port `5580`; withdraw when HTTP down / no LAN IP
- [x] 6.2 Add overlay/helper scripts if Avahi publish needs rootfs support; document browse verification
- [x] 6.3 Confirm LAN RTSP `rtsp://<device-ip>:8554/camera/pr0` reachability; decide/implement camera HTTP `:9000` proxy only if still required

## 7. Verification and docs

- [x] 7.1 Unit/widget tests for origin pin, envelope codec, lock store, local health route
- [x] 7.2 Manual checklist: proxy on/off cloud probe+WS; unbound QR bind; LAN discover + `:5580`; OTA WS command no-op
- [x] 7.3 Update `docs/flutter-linux-hmi-plan.md` / README P4 notes for cloud+`:5580` progress; note OTA remains separate
- [x] 7.4 Resolve open question with mobile on `http`/`5580` vs legacy `ws`/`9527` and record outcome in design or follow-up change
