## ADDED Requirements

### Requirement: Production infer stream notifies camera AI SSE lifecycle

When **`GET /v1/camera/ai`** has one or more active SSE subscribers, the system SHALL emit camera AI SSE lifecycle events tied to the production PR1 infer stream:

- **`start`** when `ProductionInferenceStreamClient` successfully starts the infer RTSP session (laser ON).
- **`stop`** with `reason` `laser_off` when the infer stream stops due to laser OFF.
- **`stop`** with `reason` `stream_error` when the infer RTSP session fails irrecoverably.
- **`stop`** with `reason` `release` on app shutdown or explicit client release.

When zero subscribers are connected, the system MUST NOT emit these SSE events (infer stream behavior is unchanged).

#### Scenario: Laser on notifies subscribers

- **WHEN** laser turns ON, production infer stream starts, and at least one `/v1/camera/ai` subscriber is connected
- **THEN** all camera AI SSE subscribers MUST receive `event: start` with `source` `production_weld` before the first `running` of that session

#### Scenario: Laser off notifies subscribers

- **WHEN** laser turns OFF while subscribers are connected
- **THEN** all camera AI SSE subscribers MUST receive `event: stop` with `reason` `laser_off` for the ending session

#### Scenario: No subscribers skips SSE lifecycle

- **WHEN** laser turns ON but zero `/v1/camera/ai` subscribers exist
- **THEN** production infer stream MUST still start per existing requirements
- **AND** the system MUST NOT emit `start` or `stop` on the camera AI SSE hub
