## ADDED Requirements

### Requirement: Production inference uses inferFromI420 on a background worker

In Quick Mode and Engineer Mode, when the production sub-stream sampling gate accepts an I420 frame and laser is ON, the system SHALL submit `LensGuardManager.inferFromI420` on a background executor (not the RTSP decode callback thread). The decode callback MUST remain non-blocking.

#### Scenario: Decode callback stays non-blocking

- **WHEN** the inference RTSP client delivers I420 at video frame rate but the 2000 ms gate accepts a frame
- **THEN** the decode callback MUST return without blocking on unified infer completion
- **AND** unified infer MUST run on the designated worker thread

#### Scenario: Laser off stops worker submissions

- **WHEN** laser turns OFF and the inference client stops
- **THEN** no new `inferFromI420` tasks MUST be started
- **AND** any in-flight unified infer MAY complete or time out without starting new work

### Requirement: Production on-frame compositing only when camera AI HTTP has subscribers

In Quick Mode and Engineer Mode, the system SHALL draw detection boxes and status text **into composited video frames** and produce a composited encoded stream for **`GET /v1/camera/ai`** **only while at least one HTTP subscriber** is connected and composited mode is active. When **no** `/v1/camera/ai` subscriber is present, production MUST NOT run the compositor encoder loop or burn overlay into frames for display; it SHALL limit itself to underlying LensGuard behavior (e.g. `inferFromI420` hold-forward for engine state, stain **warnings**, alerts, logs, `nativeSetLaserOn` semantics) without generating a new composited PR1 video product for operators or LAN clients.

#### Scenario: LAN client opens camera AI stream

- **WHEN** a client connects to `GET /v1/camera/ai` while laser is ON and production inference is streaming
- **THEN** the system MUST composite PR1 frames with hold-forward `LensGuardInferenceResult` (boxes + status text on bitmap) and encode H.264/TS for that session
- **AND** composited output MUST update when newer completed samples arrive

#### Scenario: No HTTP subscriber

- **WHEN** production inference is active (laser ON, PR1 streaming) but zero `/v1/camera/ai` subscribers exist
- **THEN** the system MUST NOT encode composited PR1 video solely for on-device Quick/Engineer UI
- **AND** MUST still allow lens-guard warnings, logging, and alert paths driven by unified infer results

#### Scenario: Last subscriber disconnects

- **WHEN** the final `/v1/camera/ai` subscriber disconnects
- **THEN** composited encode for production MUST stop
- **AND** background `inferFromI420` MAY continue for underlying monitoring per product policy

### Requirement: Production path drops samples when unified infer is in flight

When a production-sampled frame arrives while a prior unified infer is still in flight, the system SHALL drop the new sample and MUST NOT enqueue a second concurrent unified infer. Hold-forward rules apply to compositing when HTTP compositing is active.

#### Scenario: Busy during weld sampling

- **WHEN** the 2000 ms gate accepts a frame but unified infer is already in flight from the previous sample
- **THEN** the new frame MUST be ignored for infer scheduling purposes
- **AND** the production RTSP session MUST continue decoding without stalling
