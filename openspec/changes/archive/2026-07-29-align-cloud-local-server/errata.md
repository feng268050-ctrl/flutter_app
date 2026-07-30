# Errata — align-cloud-local-server (2026-07-29 archive)

The archive [tasks.md](tasks.md) marked several Local HTTP items complete before full lws-ui parity landed. Corrective work (2026-07-30) rewrote `:5580` handlers and the main `device-local-http-api` spec.

| Task | Archive claim | Actual at archive time | Corrected |
|------|---------------|------------------------|-----------|
| 5.3 videos upload | `[x]` wired upload | No `POST /v1/videos`; path ids used SQLite row id; list lacked filters | Multipart upload, `videoId` paths, `query()` filters |
| 5.5 monitor/camera | `[x]` routes or 501 stubs | Blanket `/v1/monitor/*` and `/v1/camera/*` → 501 | Monitor SSE; camera record/overlay/ai contracts |
| 5.3/ADB shape | implied success | `/v1/adb` returned non-null `data` object | Success `data: null` |

Do not treat the archive checkboxes as evidence that upload/SSE/camera were production-complete at archive time.
