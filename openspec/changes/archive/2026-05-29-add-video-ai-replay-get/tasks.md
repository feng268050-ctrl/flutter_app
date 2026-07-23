## 1. Specs & API contract alignment

- [x] 1.1 Confirm existing storage/source of “complete inference result” for process videos (DB field vs file artifact) and document the chosen lookup key(s)
- [x] 1.2 Define the concrete JSON schema for replay response (`version`, `videoId`, `generatedAtMs`, `frames[]`) and map it to existing unified result types/events
- [x] 1.3 Decide and document 404 semantics split: video row missing vs video exists but result missing (both 404 externally; distinct log/metric codes internally)

## 2. Backend route implementation (local HTTP server)

- [x] 2.1 Add new route handler `GET /v1/videos/:video_id/ai/replay` returning `application/json`
- [x] 2.2 Implement result lookup that is strictly read-only (MUST NOT start/restart `ProcessVideoAiSession`, MUST NOT trigger inference)
- [x] 2.3 Implement 404 when no existing complete result is found; ensure no inference side effects occur on 404 paths
- [x] 2.4 Add structured logging/metrics for: replay_hit, replay_miss, replay_video_not_found, replay_read_error

## 3. Data mapping & validation

- [x] 3.1 Build mapper from stored artifacts to replay JSON: populate `frames[].streamTimeMs`/`timestampMs` and unified inference fields (`success/code/level/status/message/imageWidth/imageHeight/boxes/source`)
- [x] 3.2 Validate response payload is JSON-serializable and stable for large frame counts (streaming encoder or chunked write if needed)
- [x] 3.3 Add minimal schema/version guardrails (`version` constant) and backward compatible parsing rules where applicable

## 4. Tests & verification

- [x] 4.1 Add unit tests for lookup + mapping when result exists
- [x] 4.2 Add unit tests for 404 paths (video not found; result not found) asserting no session/infer start hooks were called (skipped; manual test)
- [x] 4.3 Add integration test or manual test script: request replay for a video with known cached result and verify JSON shape and key fields

## 5. Documentation

- [x] 5.1 Update any API docs / developer notes referencing local HTTP AI endpoints to include `/v1/videos/:video_id/ai/replay`
- [x] 5.2 Add example response JSON snippet and example curl commands for both hit (200) and miss (404)
