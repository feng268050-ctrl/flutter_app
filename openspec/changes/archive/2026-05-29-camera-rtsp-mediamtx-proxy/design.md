## Context

The HMI exposes an embedded LAN HTTP server on **`0.0.0.0:8080`**. **`GET /v1/camera/live`** pulls `CameraConfig.RECORDING_RTSP_URL` (`rtsp://192.168.1.100/PR0`) via `EasyPlayerClient`, fans out Annex-B H.264 or MPEG-TS over HTTP chunked responses. Field issues: intermittent frame delivery, wedged state after client disconnect, duplicate PR0 RTSP when recording is active.

Stakeholders: LAN mobile apps, ffplay/VLC, Flutter integrators, and internal AI Vision docs that pair video with SSE overlays. Device: RK3588 tablet, Android system app; camera on eth0 (`192.168.1.100`), clients on Wi‑Fi/LAN reach device IP.

An in-flight change (`camera-live-http-ffmpeg-h264`) swaps the HTTP bridge to ffmpeg; **this change supersedes that approach** with MediaMTX and **removes the HTTP route entirely**.

## Goals / Non-Goals

**Goals:**

- Run **MediaMTX** as a **subprocess** with YAML config generated on device.
- **One upstream pull** of `/PR0`; **many RTSP readers** on the device without per-client camera sessions.
- **APK carries** binary + default config template; **start/stop** under app control with refcount or explicit enable policy.
- **OTA-upgradable** binary using existing `lws-app` semver + zip artifact patterns (parallel to AI library / optional native payloads).
- **Observability**: structured logs (PID, config path, path names, exit code, stderr tail), health probe for “relay ready”.
- Document stable client URL: **`rtsp://<device-lan-ip>:8554/camera/pr0`** (defaults; spec may adjust port/path).
- **Fast / Engineer process-video recording** and **`POST /v1/camera/record`** ingest from **`rtsp://127.0.0.1:8554/camera/pr0`** (loopback relay reader), never directly from `rtsp://192.168.1.100/PR0`.

**Non-Goals:**

- HTTP live streaming, HLS, WebRTC, or MPEG-TS over HTTP.
- Replacing `GET /v1/camera/ai`, PR1 inference, or in-app `TextureView` preview pipelines.
- Transcoding (relay MUST be pass-through / remux-only; no decode-reencode).
- Shipping MediaMTX for non-`arm64-v8a` ABIs in v1 unless build pipeline already multi-ABI.

## Decisions

### Replace HTTP live with LAN RTSP relay (BREAKING)

**Decision:** Remove `GET /v1/camera/live`. Publish PR0 via MediaMTX path **`camera/pr0`** on **`0.0.0.0:8554`** (RTSP).

**Rationale:** Matches user request (“RTSP 分流代理”); standard players; avoids custom HTTP pump bugs.

**Alternatives considered:**

- Keep HTTP + MediaMTX: doubles surface area; rejected.
- ffmpeg subprocess HTTP bridge (`camera-live-http-ffmpeg-h264`): still custom HTTP semantics; rejected in favor of this change.

### MediaMTX `path` pulls camera once (`source: publisher` + `runOnDemand` vs `source: rtsp://`)

**Decision:** Use a **static path** with **`source: rtsp://192.168.1.100/PR0`** (from `CameraConfig`, injected at config render time) and **`sourceProtocol: tcp`**. Enable **`sourceOnDemand: yes`** so upstream connects when the first reader attaches and disconnects after idle timeout (aligns with “stop when unused”).

**Rationale:** Native fan-out; idle upstream teardown reduces camera load.

**Alternative:** Always-on pull — simpler but wastes camera bandwidth; use only if on-demand proves flaky in field tests.

### APK lifecycle coordinator

**Decision:** Introduce `MediaMtxRelayCoordinator` (name TBD) owned by application scope:

1. On first need (configurable: **app start** vs **lazy on first external subscribe** — default **lazy** to avoid idle camera pull), extract assets → `files/mediamtx/<version>/mediamtx` + render `mediamtx.yml` from template.
2. `ProcessBuilder` exec with **`--conf`** pointing at rendered YAML; set executable bit after extract.
3. **Reference count** (recording leases + optional explicit “keep warm”): coordinator ensures MediaMTX is running while any in-app recorder holds a lease or external policy requires it; on app terminate, `destroy()` process tree.
4. Watchdog: if process exits unexpectedly while relay should be active, restart with exponential backoff cap.

**Rationale:** Matches “apk 携带和启停”; keeps Java layer authoritative for lifecycle.

### Bundled binary build (`make mediamtx`)

**Decision:**

- Vendor MediaMTX source at pinned tag (e.g. `v1.x.y`) under `tools/mediamtx/`.
- `scripts/ci/build-mediamtx.sh` cross-compiles with `GOOS=android GOARCH=arm64` (CGO disabled).
- Output: `app/src/main/assets/mediamtx/arm64-v8a/mediamtx` + `version.txt` (and optional `mediamtx.yml` template).
- `assets/mediamtx/` gitignored; CI/Makefile copies before `assemble`.
- Record license (MIT) in `NOTICE` / docs.

**Rationale:** Same pattern as bundled firmware / ffmpeg experiment.

### OTA upgrade path

**Decision:** Add optional OTA artifact **`mediamtx`** in `lws-app` zip (alongside `ai-library`, etc.):

- Filename or manifest entry carries **semver** (e.g. `mediamtx-1.9.0-arm64-v8a.zip`).
- On OTA apply / next cold start: compare with `files/mediamtx/installed-version`; if newer, atomically replace binary directory and bump version file.
- If relay running during OTA, **defer** swap until stop or schedule restart with user-visible log (no mid-stream file replace).

APK-bundled semver **≥** OTA only when APK is newer; OTA can patch field devices between APK releases.

**Rationale:** Satisfies “可随 OTA 升级” without new cloud contract beyond existing zip layout.

### PR0 recording consumes MediaMTX fan-out (single upstream)

**Decision:** All in-scope PR0 recording (`EasyPlayerClientManger.start()`, invoked from Fast/Engineer `CameraController` and `CameraRecordCoordinator` / `POST /v1/camera/record`) SHALL use a **canonical relay reader URL**:

**`rtsp://127.0.0.1:8554/camera/pr0`**

exposed via e.g. `MediaMtxRelayUrls.localPr0()` (name TBD). The app MUST NOT pass `CameraConfig.RECORDING_RTSP_URL` to `EasyPlayerClient` for these record paths after this change.

**Coordinator coupling:** Starting recording MUST **acquire a relay lease** (start MediaMTX if not running, increment refcount) before `EasyPlayerClient.start(relayUrl, …)`. Stopping recording releases the lease; MediaMTX MAY stop when refcount hits zero and no LAN readers remain (subject to `sourceOnDemand`).

**Rationale:** Satisfies “上游 PR0 仅有一个消费者” — only MediaMTX talks to the camera; record + LAN viewers are downstream readers on `camera/pr0`.

**Alternatives considered:**

- Direct camera RTSP for record + MediaMTX for LAN: duplicate upstream; rejected.
- Encoded-frame tap from recorder into MediaMTX: more Java glue; rejected for v1.

### Coexistence with PR0 recording and LAN viewers

**Decision:** Recording while LAN clients watch `rtsp://<device-lan-ip>:8554/camera/pr0` is **normal**: both are readers on the same MediaMTX path; **no** `duplicate_rtsp=recording_active` when all consumers use the relay.

**Rationale:** Replaces the old HTTP-live + record duplicate-session workaround.

### Security / exposure

**Decision:** Bind RTSP **`0.0.0.0:8554`** on LAN only (same trust model as `:8080`). No authentication in v1 (camera credentials stay on upstream URL only in generated config on device). Document that LAN clients must not expose device IP to untrusted networks.

### Discovery (optional follow-up)

**Decision:** Do **not** require mDNS in v1; document URL in API reference. Optional later: `_rtsp._tcp` advertisement via existing `device-mdns-service-advertising`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| MediaMTX binary size (~10–20 MB) | Strip unused features in build; single ABI; compress in OTA zip |
| SELinux / executable from app data | Extract to `filesDir`, `chmod 700`, test on RK3588 userdebug/production images |
| Zombie/orphan processes | `destroyForcibly` on teardown; register shutdown hook |
| Client breakage (HTTP → RTSP) | **BREAKING** migration section in docs; major version note |
| `sourceOnDemand` latency on first viewer | Tune `sourceOnDemandStartTimeout`; document warm-up |
| OTA mid-relay | Defer binary swap until idle |
| Overlaps `camera-live-http-ffmpeg-h264` | Close/supersede that change before apply |
| Record start before relay ready | Block record with existing “recorder unavailable” UX; log `relay_not_ready` |
| Loopback RTSP to localhost | Use `127.0.0.1`; verify MediaMTX accepts local readers on RK3588 |

## Migration Plan

1. Ship MediaMTX coordinator behind internal flag if needed for one release; default off → on after soak (or ship direct if confident).
2. Remove HTTP route and publisher classes; update all doc examples to RTSP URL.
3. Notify integrators: replace `http://<ip>:8080/v1/camera/live` with `rtsp://<ip>:8554/camera/pr0`; ffplay/VLC use RTSP demuxer (no `-f h264` HTTP hack).
4. Rollback: revert APK; OTA cannot downgrade binary without explicit older payload — keep previous binary in backup dir until new version confirmed.

## Open Questions

- **Lazy vs app-start relay:** default lazy for LAN-only; recording start always implies relay lease (starts process on first record if needed).
- **BackgroundLoopRecorder:** migrate to relay URL in same change or immediate follow-up — recommend same PR to preserve global single-upstream invariant.
- **Exact port/path:** default `8554` / `camera/pr0` — confirm no conflict with other services on device.
- **OTA manifest field name:** align with backend `staging.json` / `release.json` schema owners before implementation.
