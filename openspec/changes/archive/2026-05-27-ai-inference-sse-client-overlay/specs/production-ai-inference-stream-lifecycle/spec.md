## MODIFIED Requirements

### Requirement: Production on-frame compositing only when camera AI HTTP has subscribers

In Quick Mode and Engineer Mode, production inference (`ProductionInferenceStreamClient`) SHALL continue **`inferFromI420`** hold-forward for engine monitoring, stain warnings, alerts, and logs. When one or more clients are connected to **`GET /v1/camera/ai`**, the system SHALL push completed production samples to the SSE publisher as **`inference`** events. The system MUST NOT run a compositor encoder or burn overlay into PR1 bitmaps for HTTP or on-device Quick/Engineer video display.

#### Scenario: LAN client opens camera AI SSE

- **WHEN** a client connects to `GET /v1/camera/ai` while laser is ON and production inference is streaming
- **THEN** the system MUST emit SSE `inference` events from hold-forward production results as samples complete
- **AND** MUST NOT return H.264 or MPEG-TS on that connection

#### Scenario: No HTTP subscriber

- **WHEN** production inference is active (laser ON, PR1 streaming) but zero `/v1/camera/ai` subscribers exist
- **THEN** the system MUST NOT encode composited PR1 video
- **AND** MUST still allow lens-guard warnings, logging, and alert paths driven by unified infer results

#### Scenario: Last subscriber disconnects

- **WHEN** the final `/v1/camera/ai` subscriber disconnects
- **THEN** SSE publishing for production MUST stop
- **AND** background `inferFromI420` MAY continue for underlying monitoring per product policy

## MODIFIED Requirements

### Requirement: Production path drops samples when unified infer is in flight

When a production-sampled frame arrives while a prior unified infer is still in flight, the system SHALL drop the new sample and MUST NOT enqueue a second concurrent unified infer. Hold-forward rules apply to SSE events and any client overlay when subscribers exist.

#### Scenario: Busy during weld sampling

- **WHEN** the 2000 ms gate accepts a frame but unified infer is already in flight from the previous sample
- **THEN** the new frame MUST be ignored for infer scheduling purposes
- **AND** the production RTSP session MUST continue decoding without stalling
