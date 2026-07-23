## Context

PR0 process-video recording is started from three entry points today:

1. **UI** — `CameraController.checkAndStartRecord()` → `CameraRecordCoordinator.runStartPreflight()` → `startRecord()` (binding + timer; encoder via existing controller wiring).
2. **HTTP** — `DeviceLocalHttpServer` → `CameraRecordCoordinator.applySwitchBlocking("on"|"off")`.
3. **Headless HTTP** — when no `CameraRecordUiBridge` controller is registered, `finishApplyOn` calls `EasyPlayerClientManger.start()` directly.

`CameraRecordCoordinator.applyOn` currently returns `Result.ok("on")` when `isRecordingActive()` is true (idempotent). `EasyPlayerClientManger.start()` also guards `client.isRecording()` but HTTP never surfaces that as a conflict to clients. Work is spread across `ThreadPoolManager` and the main thread without a single start queue.

## Goals / Non-Goals

**Goals:**

- At most **one** PR0 recording session globally (encoder + coordinator view of “active”).
- At most **one** start orchestration running at a time (serialized on a dedicated single-thread executor owned by `CameraRecordCoordinator`).
- Any second **start** while active → failure with message **`另一个线程正在录制中`** (UI toast + HTTP `ApiResult` failure).
- Preserve existing preflight checks, stop semantics, UI bridge sync, and MediaMTX ingest path.

**Non-Goals:**

- `elapsed` / timeline fields in HTTP `data` (see abandoned `camera-record-single-thread-timeline` draft).
- Changing background loop recorder (`BackgroundLoopRecorder`) — out of PR0 HTTP/UI scope.
- Changing idempotent **`switch: "off"`** when already idle.

## Decisions

### 1. Dedicated serial executor for record control

**Decision:** Add a private `ExecutorService` (single thread, named e.g. `camera-record-control`) inside `CameraRecordCoordinator`. Route `applySwitch`, `applySwitchBlocking`, and the worker portion of `runStartPreflight` (sync checks + camera check callback chain) through this executor. Post UI callbacks (`finishApplyOn`, toasts) to `mainHandler` as today.

**Rationale:** Meets “只允许一个线程启动录像” literally for orchestration and eliminates races between two HTTP posts or HTTP vs UI preflight.

**Alternative:** Synchronize on a monitor only around `isRecordingActive()` check — rejected; still allows overlapping preflight/camera-check work.

### 2. Conflict = already recording, fail fast

**Decision:** Before running preflight for any **start**, if `isRecordingActive()` is true, return failure immediately:

- HTTP/async: `Result.fail(409, "recording_in_progress", "on")` with `errorMessage` set to the localized string (Chinese default text exactly **`另一个线程正在录制中`** per product copy).
- UI `runStartPreflight`: show the same string via `ToastUtils` and invoke `onFailMain` without starting.

**Rationale:** Replaces idempotent duplicate start with explicit integrator/operator feedback.

**Alternative:** HTTP 503 — rejected; 409 Conflict better expresses “session already exists”.

### 3. String resources

**Decision:** Add `R.string.camera_record_another_thread_recording` with zh value **`另一个线程正在录制中`** and en equivalent (e.g. “Another thread is recording”). Use for toasts and HTTP message body construction (reuse `Context`/`Utils` pattern from other local HTTP errors).

**Rationale:** Keeps copy consistent and translatable; matches user-specified Chinese text.

### 4. UI tap while recording unchanged

**Decision:** `CameraController` record button when `binding.getIsRecord()` is true continues to call `stopRecord()` — not a “start” path, no change.

**Rationale:** User requirement targets concurrent **starts** only.

### 5. Stop path stays on serial executor but remains lenient

**Decision:** `applyOff` runs on the same executor; if not recording, still return `Result.ok("off")`.

**Rationale:** Safe no-op for duplicate stop; avoids breaking existing clients.

### 6. Tests

**Decision:** Unit-test coordinator: second `applyOn` while mocked active recording returns `recording_in_progress` and does not call `EasyPlayerClientManger.start()` again. Extend route test or document expected JSON failure shape.

## Risks / Trade-offs

- **[Risk] Breaking LAN clients that relied on idempotent `switch: "on"`** → Document in `network-api-reference.md`; clients must poll `isRecordingActive` via failed start or observe UI/device state.
- **[Risk] UI preflight queued behind long HTTP start** → Acceptable; single-thread queue is intentional; HTTP timeout (90s) already bounds wait.
- **[Risk] `isRecordingActive()` false while encoder still starting** → Re-check on serial thread immediately before `start()` / `applyExternalRecordOn`; keep `EasyPlayerClientManger.start()` guard as last resort.

## Migration Plan

1. Implement coordinator + strings + UI toast.
2. Update specs/docs and tests.
3. Ship in next app release; inform integrators that duplicate `switch: "on"` returns 409 `recording_in_progress`.

## Open Questions

- None blocking implementation; confirm with product that English copy for the toast/HTTP message is acceptable alongside the mandated Chinese string.
