## Context

Network ADB on Innohi boards is enabled today through a **hidden gesture** on **Settings → Device Information**: five consecutive taps on **System Version** within a **5 s** window (`SecretTapTracker`), which calls `AdbRemoteDebugHelper.enableRemoteDebugging` on a background executor. That helper sets `Settings.Global.ADB_ENABLED`, configures TCP port **5555** via `setprop`, and restarts `adbd` with root shell commands.

The embedded **`DeviceLocalHttpServer`** already exposes multiple **`/v1/*`** JSON and SSE routes on **`0.0.0.0:5580`** for LAN clients. Operators and factory tools need the **same ADB enablement** without the hidden UI step, using the established **`ApiResult`** envelope and LAN trust model.

## Goals / Non-Goals

**Goals:**

- Add **`POST /v1/adb`** that calls **`AdbRemoteDebugHelper.enableRemoteDebugging`** — the identical code path as the five-tap gesture (not a reimplementation).
- Return **`ApiResult`** with **`success: true`**, HTTP **200**, and **`data: null`** on logical success.
- Return **`ApiResult`** failure with a diagnosable **`message`** when enablement fails.
- Register the route in `DeviceLocalHttpServer.serve` alongside existing `/v1/*` handlers.
- Document curl example and response shape in `docs/network-api-reference.md`.

**Non-Goals:**

- Local HTTP authentication, TLS, or cloud Worker exposure.
- Changing `SecretTapTracker` / five-tap UI behavior.
- Returning TCP port or shell output in the response (`data` stays **`null`** on success).
- Disabling ADB or adding `DELETE` / `GET` variants.
- Requiring five HTTP calls or a request body (single `POST` triggers enablement).

## Decisions

### 1. Reuse `AdbRemoteDebugHelper` directly

**Decision:** HTTP handler invokes `AdbRemoteDebugHelper.enableRemoteDebugging(appContext)` and maps its boolean result to `ApiResult` success/failure.

**Rationale:** Matches the user requirement that constraints and effects are the same as the System Version secret tap. Avoids duplicated `setprop` / `Settings.Global` logic.

**Alternative considered:** Inline shell commands in the HTTP handler — rejected (drift risk).

### 2. No request body

**Decision:** `POST /v1/adb` accepts an empty body (or ignores any body). No JSON fields.

**Rationale:** Enablement is a single fire-and-forget action; mirrors the tap gesture which carries no parameters. Keeps client integration minimal (`curl -X POST`).

### 3. Threading

**Decision:** Run `enableRemoteDebugging` on **`ThreadPoolManager`** executor (same as `DeviceInformationFragment`), block the NanoHTTPD handler thread on a short `Future.get` with timeout, or use a latch — prefer the same pattern as `serveCameraRecord` if it offloads work.

**Rationale:** `Settings.Global` and root shell calls must not run on the main thread; HTTP response should reflect actual enablement outcome.

**Note:** Inspect `serveCameraRecord` / coordinator for the established offload + wait pattern and mirror it.

### 4. HTTP status and `ApiResult` codes

**Decision:**

- Success: HTTP **200**, `DeviceApiResultHttp.success(null)` → `{ "success": true, "code": 200, "message": null, "data": null }`.
- Failure: HTTP **200** with `success: false` and `code` **503** (or **500**) and `message` **`adb_enable_failed`** — align with other local routes that return business failures in `ApiResult` while keeping HTTP 200 unless the server is not ready.

**Alternative considered:** HTTP 503 without `ApiResult` — rejected (inconsistent with `/v1/camera/record` and `/v1/process-parameters`).

### 5. Idempotency

**Decision:** Repeated `POST /v1/adb` while ADB is already enabled SHALL still return **`success: true`** with **`data: null`** as long as `enableRemoteDebugging` returns true (re-applies settings and restarts `adbd`).

**Rationale:** Same as re-tapping after success; harmless and simplifies client retry logic.

### 6. UI fragment unchanged

**Decision:** `DeviceInformationFragment` keeps its five-tap `SecretTapTracker` path; optionally refactor to call a shared one-liner wrapper, but no behavior change required.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| LAN exposure enables `adb connect` without physical access | Same trust model as other `/v1/*` controls; document security implication in API reference |
| Root / `adbd` restart fails on non-root builds | Return `adb_enable_failed`; log via existing `AdbRemoteDebugHelper` |
| Blocking NanoHTTPD thread on slow shell | Offload to executor with reasonable timeout; log slow paths |
| Emulator vs device differences | No special-case; helper already used in production UI path |

## Migration Plan

1. Implement route + handler in `DeviceLocalHttpServer`.
2. Add JVM/route-level test (method routing or mocked helper).
3. Update `docs/network-api-reference.md` with `POST /v1/adb` section and curl example.
4. Archive OpenSpec change; delta merges into `device-local-http-api` and new `device-local-http-adb` spec.

**Rollback:** Remove route registration; no schema or persistence changes.

## Open Questions

- None — success `data: null` and shared helper path are specified by the request.
