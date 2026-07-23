## Context

Today `CameraDeviceInfoRefreshScheduler` fires every 1 s and calls `CameraDeviceInfoCache.refresh()`, which issues `GET /System/deviceinfo`. `CameraCommStatus.isFault()` treats cache display `-` as a communication fault, so alarms, Monitor tiles, and WS snapshots all infer connectivity from the same HTTP probe. Version and reachability are therefore coupled, and the IPC sees ~1 HTTP request per second for the app lifetime.

Field experience shows IPC HTTP may not respond immediately after eth0 is configured even when the camera is already reachable at the IP layer. Ping is sufficient for “is the camera on the LAN?” while version is static for a session and only needs a successful fetch once.

Existing building blocks: `CameraConfig.getCameraIp()`, `ShellCmdUtil.executeCmd("ping …")` (DevActivity), in-flight coalescing in `CameraDeviceInfoCache`, and `clearAndRefresh` on network segment changes.

## Goals / Non-Goals

**Goals:**

- Run **1 Hz ping** to the configured camera IP on a background executor; expose `CameraCommStatus` from ping result, not version cache.
- Fetch camera **version once per cache epoch** via HTTP with **exponential backoff retries** until success or attempts exhausted; skip HTTP when a valid version is already cached.
- Keep normalization, `CAMERA_VERSION_DISPLAY` notifications, Settings row, and WS `deviceInfo.cameraVersion` behavior unchanged for consumers that read `CameraDeviceInfoCache.getDisplay()`.
- Invalidate and re-run backoff fetch on existing triggers (`setCameraNetworkSegment`, `clearAndRefresh`, explicit Settings refresh).

**Non-Goals:**

- Changing camera IP configuration, RTSP/MediaMTX paths, or NanoHTTPD proxy routes beyond swapping connectivity gates to ping.
- Persisting version in Room or adding OTA-driven version re-fetch.
- Replacing ping with TCP connect to port 9000 (ping chosen for minimal IPC load; revisit if ICMP blocked on some SKUs).

## Decisions

### 1. New `CameraPingHealth` module + repurpose scheduler

- **Decision**: Introduce `CameraPingHealth` (singleton) holding atomic `reachable` flag updated by ping worker; rename/repurpose `CameraDeviceInfoRefreshScheduler` → `CameraPingHealthScheduler` posting 1 Hz ticks that call `CameraPingHealth.probeAsync()`.
- **Rationale**: Clean separation from version cache; existing scheduler start/stop in `LaserApplication` stays one line.
- **Alternative considered**: Embed ping in `CameraCommStatus` directly — rejected; scheduler and test hooks already exist.

### 2. Ping command and threading

- **Decision**: Background thread pool probe: `ping -c 1 -W 1 <CameraConfig.getCameraIp()>`, success when shell exit code is 0. Coalesce in-flight probes (skip tick if previous ping still running).
- **Rationale**: Matches DevActivity pattern; `-W 1` bounds latency per tick; single packet minimizes load.
- **Alternative**: `InetAddress.isReachable()` — rejected; behavior varies by Android/kernel and may require CAP_NET_RAW.

### 3. `CameraCommStatus` reads ping, not cache

- **Decision**: `isFault()` → `!CameraPingHealth.isReachable()`; `isHealthy()` negates. Version `-` with ping OK is **not** a comm fault.
- **Rationale**: Matches user intent; version may lag while HTTP warms up without raising C002.

### 4. Version fetch: fetch-once with exponential backoff

- **Decision**: `CameraDeviceInfoCache` tracks `versionResolved` (valid display ≠ `-`). When unresolved and no fetch in flight, schedule backoff attempts: delays **1 s, 2 s, 4 s, 8 s, 16 s** (5 tries, ~31 s window). On HTTP 2xx + valid `appVersion`, set cache and stop retrying for this epoch. On exhaustion, leave `-` until explicit `clearAndRefresh` / network event / Settings refresh.
- **Rationale**: Tolerates IPC HTTP startup without periodic polling; bounded total wait.
- **Alternative**: Infinite retry — rejected; would eventually resume HTTP load.

### 5. Trigger points

- **Decision**:
  - **Ping scheduler**: start/stop with app (unchanged lifecycle).
  - **Version backoff**: start on `setCameraNetworkSegment` success, app init if eth0 already up, and `clearAndRefresh`; do **not** start on every ping tick.
  - **Settings Device Information**: optional `refresh()` still allowed; if version already cached, no-op HTTP unless forced clear.
- **Rationale**: Minimizes HTTP; explicit refresh remains for support.

### 6. `CameraUtils` connectivity gates

- **Decision**: `checkCamera` / `checkCameraBlocking` await latest ping result (with short timeout, e.g. 2 s) instead of deviceinfo refresh; success when ping reachable.
- **Rationale**: NanoHTTPD routes need fast connectivity gate without waking IPC HTTP stack.

## Risks / Trade-offs

- **[Ping OK but HTTP down]** → Comm shows healthy; version may stay `-` until backoff completes or operator opens Settings. Acceptable: comm alarm is IP-layer; version is informational.
- **[Ping blocked, HTTP OK]** → False C002 fault. Mitigation: document; future TCP:9000 probe if reported on hardware.
- **[Stale version after IPC OTA without app restart]** → Version won't refresh until cache invalidation. Accepted non-goal; OTA typically reboots both sides.
- **[Shell ping requires privileges]** → Same as existing DevActivity ping; fails closed to fault if command cannot run.

## Migration Plan

1. Land ping module + switch `CameraCommStatus` and scheduler.
2. Refactor `CameraDeviceInfoCache` backoff; remove HTTP from scheduler tick.
3. Update tests and alarm transition specs.
4. Rollback: revert commit; scheduler returns to HTTP mode (no schema migration).

## Open Questions

- Confirm 5 backoff steps (~31 s) is sufficient for slow IPC HTTP boot on target hardware, or adjust constants after field trial.
- Whether emulator without `camera_ip` should skip ping scheduler entirely (preserve current neutral comm tile behavior).
