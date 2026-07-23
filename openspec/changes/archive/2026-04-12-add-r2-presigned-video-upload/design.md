## Context

- **Current**: `VideoAndProcessParamsHandler` obtains Aliyun OSS via `OSSCredentialProviderManger` + `RequestApi.getAccountAuthRemote()`, uploads cover image and video through the OSS SDK, builds `ProcessVideo.videoUrl` from bucket/region/key, then POSTs `ProcessParamsVideo` via `ProcessApi.uploadVideoAndProcessData` (Retrofit `ProcessVideoRemoteApi`).
- **Target**: Issue a **presigned PUT** from the **Cloudflare Worker** already distinguished by channel (`BuildConfig.RELEASE_CHANNEL`), using the **same hostname resolution** as device WebSocket (`DeviceWebSocketConfig.resolveApiHost()` → `api-prod.lasercyber.workers.dev` vs `api-test.lasercyber.workers.dev`).
- **API**: `GET https://{apiHost}/upload/device/presigned-put?sn=...&content_type=...&file_name=...&key=uploads/devices/{sn}/{date}/{file_name}` returning JSON `ApiResult` with optional `data` containing `upload_url`, `method`, `public_url`, `key`, `expires_in_seconds`.

## Goals / Non-Goals

**Goals:**

- Implement a small HTTP client path (OkHttp is already a project dependency via Retrofit) to **presign** and **PUT** the local video file to `upload_url`.
- **Always** read and parse the presign response body as `ApiResult` JSON, **independent of HTTP status code**, and map failures to user-visible or logged errors using `message` / `success` / `code`.
- Build `key` (and date segment) deterministically on the device: `uploads/devices/{sn}/{yyyy-MM-dd}/{file_name}` (or equivalent agreed date format — see Open Questions).
- Keep **cover image** behavior unchanged in the first iteration unless product requires R2 for images too (non-goal below).

**Non-Goals:**

- Implement or deploy the Worker / R2 bucket policy (server-side contract only assumed).
- Remove legacy OSS entirely in v1 unless explicitly scoped in tasks (prefer **branch or staged cutover** to reduce regression risk).
- Change WebSocket protocol or `device-ws-unified-envelope` behavior.

## Decisions

1. **Worker base URL** — **Reuse `DeviceWebSocketConfig.resolveApiHost()`** and form `https://{host}/upload/device/presigned-put`. **Rationale**: Single source of truth for prod vs test, matching user requirement and existing `wss://` host pairing. **Alternative**: Duplicate hosts in `BuildConfig` — rejected (drift risk).

2. **HTTP stack for presign + PUT** — **OkHttp `Call` outside Retrofit** for presign (simple GET, custom error-body handling) and for raw PUT of file bytes (streaming `RequestBody` from file). **Rationale**: Retrofit’s default `Response` handling often treats non-2xx as error before Gson runs; contract requires parsing body on any status. **Alternative**: Retrofit + custom `CallAdapter` / `HttpException` body parse — possible but heavier for one endpoint.

3. **Success criteria for presign** — Treat as success only when JSON parses, `success == true`, and `data` is non-null with non-empty `upload_url` and `method` equal to `PUT` (case-insensitive compare). Otherwise use `message` or generic fallback.

4. **Video PUT** — Use presigned URL as absolute URL; set `Content-Type` to the same `content_type` sent to presign; use `PUT` with body length from file; follow redirects only if presigner requires (default OkHttp behavior). On 2xx, proceed to existing metadata POST with `public_url` (or constructed URL) as the canonical video URL field — **align with backend** expectations (see Open Questions).

5. **Order of operations** — Preserve current UX where possible: validate file → (cover still OSS or local) → **register metadata** might need video URL **before** or **after** upload depending on backend; design default: **if backend still requires `videoId` before bytes**, keep current POST-first pattern but pass **`public_url` from presign response** into `ProcessVideo` instead of OSS URL, **after** presign succeeds and **before** PUT, **only if** server accepts URL before object exists — **if not**, swap order to PUT-then-POST (tasks will confirm with API owner). Document both in tasks as a decision gate.

## Risks / Trade-offs

- **[Risk] Presign succeeds but metadata POST fails** → user has orphan object in R2. **Mitigation**: log `key`/`public_url`, surface retry; optional future Worker lifecycle cleanup (out of scope).

- **[Risk] Clock skew / expiry** → PUT rejected. **Mitigation**: presign immediately before upload; if PUT fails with 403, optionally single presign retry.

- **[Risk] Large files / memory** — **Mitigation**: stream file via OkHttp `RequestBody`; avoid loading whole file into heap.

- **[Trade-off] OSS + R2 in parallel** — temporary complexity during migration; mitigate with a single upload strategy flag or build-type switch.

## Migration Plan

1. Land presign client + PUT behind a **feature flag** or `BuildConfig` field defaulting to OSS until validated on hardware.
2. Run end-to-end on **test** Worker host, then **prod** channel build.
3. After stable metrics, remove OSS video path and unused STS fields if no longer referenced (**BREAKING** release note).

## Open Questions

- **Date format** in `key`: confirm Worker expects `yyyy-MM-dd` vs UTC date vs `yyyy/MM/dd` (proposal uses `{date}` placeholder).
- **Metadata POST contract**: does `ProcessVideoRemoteApi.uploadVideoAndProcessData` require the object to exist before POST, or only a final URL? Determines PUT-before-POST vs current POST-before-upload ordering.
- **Cover image**: remain on OSS only for this change, or also presign to R2 (separate key prefix)?
