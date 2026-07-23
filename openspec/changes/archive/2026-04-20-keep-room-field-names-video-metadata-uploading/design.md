## Context

`video.metadata` and `video.uploading` payloads are built in Java (`DeviceWsVideoMetadataPayload`, `DeviceWebSocketConnectionManager#sendVideoUploading`) by manually putting **snake_case** strings into `Map<String, Object>`, while the source of truth `ProcessParamsVideo` uses **camelCase** Lombok accessors (`videoId`, `uploadStatus`, …). The canonical specs in `openspec/specs/` currently mandate snake_case for those two envelopes.

## Goals / Non-Goals

**Goals:**

- Define the wire contract so JSON keys for `video.metadata` and `video.uploading` match the Room/Java bean names (camelCase), eliminating redundant renaming in app code and specs.
- Keep all other behavior unchanged: which fields are included or omitted on `video.metadata`, ordering relative to STS upload, throttling rules for `video.uploading`, and the no-secrets rules for both types.

**Non-Goals:**

- Changing `command.video_list_response` row maps, other WebSocket commands, or HTTP APIs that still use snake_case where historically required.
- Database migrations or `@ColumnInfo` renames on `t_params_process_video`.

## Decisions

1. **Use Java bean / Gson-style camelCase on the wire for these two types** — Same strings as typical JSON serialization of `ProcessParamsVideo` would use (`videoId`, `coverUrl`, …). Rationale: one name per concept from SQLite → entity → WebSocket; fewer bugs when adding fields. Alternative (keep snake_case) was rejected per product request to cut mapping cost.
2. **Treat this as a coordinated contract flip** — Server-side parsers must be updated or dual-read before or with the app release; document as **BREAKING** in the proposal.

## Risks / Trade-offs

- **[Risk] Server expects snake_case** → Mitigation: coordinate release or temporary dual-key support on the consumer; call out in migration plan.
- **[Risk] Inconsistent style across WS surface** → Accepted trade-off: only these two message types are aligned to the entity; other messages may remain snake_case until separately standardized.

## Migration Plan

1. Land spec deltas and implementation in the app (builders + tests).
2. Deploy or configure backend/handlers to read camelCase keys for `video.metadata` and `video.uploading` (or accept both during a transition window if needed).
3. Remove any transitional dual-key support after all producers use camelCase.

## Open Questions

- None assumed; if a downstream system cannot change quickly, agree on a short dual-key window outside this repo.
