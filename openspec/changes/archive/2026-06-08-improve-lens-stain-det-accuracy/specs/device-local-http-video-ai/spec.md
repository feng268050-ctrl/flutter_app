## MODIFIED Requirements

### Requirement: Process video session lifecycle SSE hooks

`ProcessVideoAiSession` SHALL emit camera-shared lifecycle events to its SSE hub:

- **`start`** when session processing begins (`source` **`offline_stain_detect`**, `samplingIntervalMs` **`200`**).
- **`running`** for each completed per-sample infer result during the session.
- **`running`** once more for the **temporal summary** frame after all samples complete and before **`stop`** (see `lens-stain-temporal-box-reduction`).
- **`stop`** with `reason` `session_complete` on end-of-file, `session_cancelled` on user cancel, `force_restart` on `?force=1`, or `stream_error` / `release` on failure/shutdown.

#### Scenario: Session complete stop

- **WHEN** playback clock reaches end-of-file and the session finishes
- **THEN** all subscribers MUST receive a summary `running` event with reduced boxes when reduction runs
- **AND** MUST receive `event: stop` with `reason` `session_complete` after that summary `running`
- **AND** the connection MAY close or return to idle per existing semantics
