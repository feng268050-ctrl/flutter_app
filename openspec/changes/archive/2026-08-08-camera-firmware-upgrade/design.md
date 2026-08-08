## Context

Control-board firmware already has the full offline ship → Home tip → Settings page → Modbus flash → host `make upgrade-control-board` loop. Camera software version is already fetched via `GET /System/deviceinfo` (`CameraDeviceInfoCache`, port **9000**, Basic `admin:admin`), and `cyber_upgrade_ui` already defines `UpgradeChannel.cameraProgram` with a stub checker that always returns unavailable.

Camera HTTP is special: OSD overlay work discovered that Dart `HttpClient` splits headers and body across TCP segments, and this MJPG-Streamer-class firmware often ignores late body bytes. The App therefore uses `DartCameraOsdHttpClient` (raw `Socket`, single write of headers+body) for OSD PUT/GET. Firmware upload (`POST /cgi-bin/cgic_upgrade` multipart) and empty-body reboot (`PUT /System/reboot`) MUST use that same wire shape.

Vendor package naming (current example): `LTC609-v1.0.7 build20260513.zip` under `app/lws_hmi/assets/firmware/camera/`. Device `appVersion` strings look like `v1.0.5 build20251127` (display via `parseCameraAppVersionDisplay` strips to SemVer for UI).

## Goals / Non-Goals

**Goals:**

- Prepare/ship only the newest camera ZIP per model (mirror control-board prune).
- Offline version gate: bundled SemVer+build strictly newer than live camera `appVersion`.
- Operator UX: Home once-per-process tip + Settings camera upgrade page via `cyber_upgrade_ui`.
- Flash with CGI multipart POST; then PUT reboot; success only after camera is online again.
- Host force path: `make upgrade-camera` + `/run/hmi/` cmd watcher.
- Mutex with control-board / whole-device OTA sessions.

**Non-Goals:**

- Cloud-delivered camera OTA or signed camera packages.
- Changing RTSP/health probe ladders beyond “reachable for re-online”.
- Rebooting the HMI board after camera flash.
- Discovering dynamic `webPort` from camera network params in v1 (keep product HTTP port **9000** like OSD/deviceinfo).
- Replacing control-board Modbus upgrade.

## Decisions

### D1 — Asset naming, prune key, and version compare

- **Source dir:** `app/lws_hmi/assets/firmware/camera/` (git multi-version + README).
- **Filename pattern:** `{MODEL}-v{SEMVER} build{YYYYMMDD}.zip` (space before `build`; model alphanumeric; SemVer `X.Y.Z`; build 8-digit date). Example: `LTC609-v1.0.7 build20260513.zip`.
- **Ship prune:** selection key = **MODEL** (case-insensitive); “newest” = highest SemVer, tie-break highest build integer. Stage into `assets/.generated/firmware/camera/`; rewrite pubspec generated-ship-assets lines (same markers as control-board).
- **Runtime gate:** parse bundled filename; parse live `appVersion` for SemVer **and** build (extend beyond display-only stripping). Offer upgrade only when `(bundledSemVer, bundledBuild) > (deviceSemVer, deviceBuild)` lexicographically (SemVer first, then build). Host force skips the gate.
- **Alternatives considered:** SemVer-only compare (rejected — builds can move without SemVer bump); control-board integer HW/SW scheme (rejected — camera vendor naming differs).

### D2 — Upload payload = staged ZIP as-is

- Multipart field `name="file"`, `filename=<zip basename>`, `Content-Type: application/octet-stream`, body = ZIP bytes from ship asset (or host-uploaded path).
- Do **not** unpack `upgrade.tar.gz` on the HMI unless a later device trial proves the CGI rejects the outer ZIP (then revisit in a follow-up).
- **Alternatives:** always extract inner tar.gz (extra complexity; unclear CGI contract).

### D3 — Extend the OSD raw-socket HTTP client for POST multipart + empty PUT

- Broaden `CameraOsdHttpClient` (or a thin sibling sharing `_request`) with:
  - `postMultipartFile(...)` building `multipart/form-data` with a random boundary, single Socket write of headers + body (large firmware → allow longer timeout / optional chunked progress callbacks if write can report offsets).
  - `put` already supports empty body via `forceEmptyBody` — reuse for `PUT /System/reboot` with no JSON.
- Keep Authorization header casing (`Authorization`) and `Connection: close`.
- **Alternatives:** Dart `HttpClient` multipart (rejected — known broken against this camera stack); shell out to `curl` (rejected — harder to progress/test in Flutter; host helper may still use curl for upload-to-HMI only).

### D4 — Success = CGI 200 + reboot 200 + camera re-online

Phases for `cyber_upgrade_ui` (App-defined):

1. **transfer** — multipart POST to `http://{cameraHost}:9000/cgi-bin/cgic_upgrade`; non-200 → fail.
2. **reboot** — `PUT http://{cameraHost}:9000/System/reboot` (Content-Length 0); non-200 → fail (log; still may try wait if reboot raced).
3. **waitOnline** — poll until camera answers again (prefer `GET /System/deviceinfo` via existing cache invalidate+fetch, and/or existing IP-camera health). Timeout → fail even if flash returned 200.
4. Optional soft check: after online, compare reported version to bundled (warn/log if mismatch; host force may still succeed if online).

HMI completion tip: **no board reboot** (`UpgradeCompletionConfig` none / camera-style).

### D5 — App architecture mirrors control-board

| Piece | Camera analog |
|-------|----------------|
| `BundledFirmwareAssets` / version gate | `BundledCameraFirmwareAssets` + parse helpers |
| `ControlBoardUpgradeChecker` | real `CameraProgramUpgradeChecker` |
| `ControlBoardUpgradeCoordinator` | `CameraProgramUpgradeCoordinator` |
| `ControlBoardUpgradePage` | `CameraProgramUpgradePage` |
| Home `BundledFirmwareBootstrap` | extend to evaluate camera after/with control-board (same once-per-process tip budget; prefer one tip at a time — if both candidates, control-board first then camera on next Home visit **or** queue camera after control-board tip dismissed; design choice: **control-board first**, camera check runs after CB tip settled / no CB candidate) |
| `SyncFirmwareCommandWatcher` | extend or add `upgrade-camera.cmd` watcher |
| `FirmwareUpgradeCoordinator` mutex | include camera session |

Host: `scripts/upgrade-camera.sh` + `make upgrade-camera` reads **source** `assets/firmware/camera/` (newest or `FIRMWARE_ZIP=`), SCP to `/run/hmi/camera-upgrade/`, writes `upgrade <path>` to `/run/hmi/upgrade-camera.cmd`.

### D6 — UI entry points

- Product Home: bundled tip dialog (`UpgradeChannel.cameraProgram`) when candidate and camera reachable.
- Settings → Device Information (and/or IP Camera settings) **Camera Version** row navigates to `CameraProgramUpgradePage` (parity with Control Board Version → control-board page).
- Progress: transfer percent when available; reboot/wait phases indeterminate.

## Risks / Trade-offs

- **[Risk] Large ZIP single-write / memory** → Mitigation: stream Socket writes in chunks while keeping HTTP framing correct; bound timeout (e.g. several minutes); surface indeterminate progress if byte progress is awkward.
- **[Risk] CGI expects inner `upgrade.tar.gz` not outer ZIP** → Mitigation: document trial; keep extract path as follow-up if field fails.
- **[Risk] Camera stays down after flash (brick / long boot)** → Mitigation: generous wait timeout + clear failure tip; host force for recovery retry; do not claim success on CGI 200 alone.
- **[Risk] Port mismatch (doc webPort 80 vs product 9000)** → Mitigation: v1 hardcode 9000 consistent with OSD/deviceinfo; open question if a property ever overrides.
- **[Risk] Concurrent Home tips for CB + camera** → Mitigation: serialize (control-board first).
- **[Trade-off] Extending OSD client vs new package** → Keep in App `ip_camera` HTTP layer to reuse auth/timeout/socket behavior; upgrade feature owns orchestration only.

## Migration Plan

1. Land assets README + ZIP(s) in `assets/firmware/camera/`; extend `prepare-hmi-ship-assets.sh`.
2. Ship App with checker/coordinator/HTTP flash + UI; push-app for boards already running.
3. Document `make upgrade-camera` beside `upgrade-control-board`.
4. Rollback: omit camera ZIPs / disable entry by not shipping assets — no rootfs schema change.

## Open Questions

- Confirm with one on-device trial whether CGI accepts the outer `.zip` or requires the inner `upgrade.tar.gz`.
- Exact re-online timeout (proposal default: **120s**, poll every 2–3s) — tune after hardware timing.
- Whether host force MUST wait for version match or only reachability.
