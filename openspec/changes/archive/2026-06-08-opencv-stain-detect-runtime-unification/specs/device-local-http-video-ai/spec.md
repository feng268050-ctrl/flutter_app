## MODIFIED Requirements

### Requirement: Process video session lifecycle SSE hooks

`ProcessVideoAiSession` SHALL emit lifecycle events to its SSE hub:

- **`start`** when session processing begins (`source` **`offline_stain_detect`**, `samplingIntervalMs` **`200`**).
- **`stop`** with `reason` `session_complete`, `session_cancelled`, `force_restart`, `stream_error`, or `release`.

#### Scenario: Session complete stop

- **WHEN** Detect playback reaches end-of-file and the session finishes
- **THEN** all subscribers MUST receive `event: stop` with `reason` `session_complete`

### Requirement: Force re-inference query parameter

When **`force=1`** is present, the system SHALL stop any existing session for that `video_id`, delete stale timeline artifacts for the current cache key, and start a new **`ProcessVideoAiSession`**. The system MUST NOT require deleting a legacy composited inference MP4 (artifact no longer produced).

#### Scenario: Force restart from HTTP

- **WHEN** `GET /v1/videos/<videoId>/ai?force=1` is requested
- **THEN** any prior session for the cache key MUST be invalidated and a new live session MUST begin
