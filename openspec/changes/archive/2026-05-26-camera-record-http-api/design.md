## Context

The HMI records process videos from **Fast Mode** (`QuickModeActivity`) and **Engineer Mode** (`EngineerModeActivity`) via the floating **`CameraController`**: preflight checks (`EasyPlayerClientManger.isRecorderReady()`, YNH local storage free space, `CameraUtils.checkCamera`), a **10-minute** `ValueAnimator` timer UI, and **`EasyPlayerClientManger.start()` / `stop()`** on PR0 (`CameraConfig.RECORDING_RTSP_URL`). Stop triggers save-to-Room, optional upload title dialog, and cover enqueue—same as today.

LAN HTTP already exposes **`GET /v1/camera/live`** (PR0 pass-through) and **`GET /v1/camera/ai`** (PR1). Remote tools need a **JSON control** route to start/stop recording without synthesizing UI clicks, while keeping on-device UX consistent when operators are on Fast / Engineer screens.

## Goals / Non-Goals

**Goals:**

- Add **`POST /v1/camera/record`** with body/response **`{ "switch": "on" | "off" }`** inside standard **`ApiResult`**.
- Reuse **one** recording orchestration path with `CameraController` (no divergent preflight or encoder rules).
- When a visible Fast / Engineer `CameraController` is active, HTTP success SHALL update **record button state, timer label, and animator** like a tap.
- Return clear **`ApiResult`** failures for invalid body, camera unavailable, insufficient storage, already on/off (idempotent success with current state where appropriate).

**Non-Goals:**

- Recording rules for other surfaces (AI Vision tab, Dev debug, background loop recorder).
- Local HTTP authentication, TLS, or cloud exposure.
- Changing `/v1/camera/live` or upload/metadata pipelines.

## Decisions

### 1. Shared coordinator vs duplicating `CameraController` logic

**Decision:** Introduce **`CameraRecordCoordinator`** (app module, `ui.network.http.local` or `ui.common.camera`) that owns the preflight + `EasyPlayerClientManger` start/stop sequence extracted from `CameraController`. Both the widget and the HTTP handler call the coordinator.

**Rationale:** Private methods in `CameraController` today cannot be invoked from `DeviceLocalHttpServer`; extraction prevents drift.

**Alternative considered:** HTTP handler reflects into `CameraController` — rejected (fragile, no headless path).

### 2. UI sync when Fast / Engineer is foreground

**Decision:** `CameraController` registers/unregisters with **`CameraRecordUiBridge`** (weak reference) in `onAttachedToWindow` / `onDetachedFromWindow`. HTTP `on`/`off` after coordinator success calls `bridge.syncUiIfPresent()` which invokes new public methods on the attached controller (`applyExternalRecordOn()` / `applyExternalRecordOff()`) that only adjust binding + animator without re-running preflight.

**Rationale:** User requirement: button animation when already on those pages. Registration avoids scanning the activity hierarchy.

**Alternative:** Broadcast `LocalBroadcast` — rejected (implicit, harder to test).

### 3. Process parameters source

**Decision:** Coordinator accepts optional **`ProcessParametersSupplier`**:

- When **`CameraRecordUiBridge`** has an active controller, supplier comes from its existing **`CameraControllerListener`** (same as tap).
- When no controller (HTTP-only while another activity is top), supplier MAY return null; save path matches today’s warning path when listener is absent.

**Rationale:** Matches “same recording as Fast / Engineer” without inventing synthetic parameters.

### 4. HTTP contract and threading

**Decision:**

- Parse JSON on NanoHTTPD thread; run coordinator work on **`ThreadPoolManager`** (same as camera checks / recorder start).
- Respond **`200`** + `ApiResult` for logical success and business failures (400 invalid body, 409 conflict optional, 503 camera/storage) — align with existing `DeviceApiResultHttp` patterns on `/v1/process-parameters`.
- **`switch: "on"`** when already recording → **`success: true`**, `data.switch: "on"` (idempotent).
- **`switch: "off"`** when not recording → **`success: true`**, `data.switch: "off"`.

**Field name:** JSON key **`switch`** (quoted in API docs; Java model may use `@SerializedName("switch")` on a field named `recordSwitch` if needed for reserved words).

### 5. Coexistence with live HTTP and UI recording

**Decision:** Coordinator consults **`EasyPlayerClientManger`** global state; does not start a second PR0 record session if one is active. `GET /v1/camera/live` behavior unchanged (existing reference-count / logging when recording active).

### 6. Post-stop UX (title dialog)

**Decision:** When stop is initiated via HTTP and a **`CameraController`** is registered, **`stopRecord()`** on that instance runs so **upload title dialog** and save hooks behave like UI stop. Headless stop uses coordinator stop + same `EasyPlayerClientManger` listener path registered once at app/coordinator init (mirror `CameraController`’s listener registration, or share a single listener delegate).

**Risk:** Headless stop might skip dialog — acceptable if no Activity context; document in API reference.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Double start (HTTP + simultaneous tap) | Idempotent `on`; coordinator checks `isRecording()` / manager state before start |
| HTTP stop while upload dialog open | Same as UI: only one active controller; serialize on main handler |
| Main-thread Room in HTTP | Coordinator save callbacks already on executor; HTTP handler stays off main for blocking work |
| No YNH on emulator | Storage check skipped (existing `CameraController` try/catch) |
| Process parameters null off-mode | Document; same as missing listener today |

## Migration Plan

1. Land coordinator + refactor `CameraController` to delegate (no HTTP yet) — regression: manual Fast / Engineer record.
2. Register route + tests + docs.
3. Field: `curl -X POST -H 'Content-Type: application/json' -d '{"switch":"on"}' http://<ip>:8080/v1/camera/record` with Fast Mode open → verify animation; stop via HTTP → verify file in library.

Rollback: remove route registration; coordinator unused if controller still calls inlined logic (keep delegation in one place).

## Open Questions

- None blocking v1. Confirm with product whether HTTP stop should **suppress** upload title dialog when Fast/Engineer is not visible (design: suppress when no attached controller).
