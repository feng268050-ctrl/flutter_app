## MODIFIED Requirements

### Requirement: Hold-forward overlay policy applies to all unified infer consumers

Callers that render detection on a moving video stream (AI Vision live RTSP, process-video playback, production PR1 monitoring, HTTP SSE `/v1/camera/ai` and `/v1/videos/:id/ai`) SHALL use the same hold-forward rule: use the latest **completed** unified result until a newer sample completes, without blocking the video path on infer.

Rendering MUST be **client-side** for display and LAN: map `LensGuardInferenceResult` to overlay geometry (`toOverlayBoxes()` or equivalent) or serialize to SSE JSON. The device MUST NOT burn boxes or status text into frame bitmaps for AI Vision preview, process-video preview, or HTTP `/ai` routes. Production Quick/Engineer modes MUST NOT run a compositor encoder for HTTP; when `/v1/camera/ai` SSE subscribers exist, production SHALL push completed samples to the SSE publisher only.

Recorded video uses timeline `findFrameAt`; live uses a monotonic `lastCompleted` snapshot—semantics are equivalent for forward playback.

#### Scenario: Live and recorded share result type

- **WHEN** live preview and recorded-video samples both complete via `inferFromI420`
- **THEN** both MUST produce `LensGuardInferenceResult` with the same `level`, `status`, and `boxes` schema
- **AND** overlay renderers MUST use `toOverlayBoxes()` or a shared mapper helper

#### Scenario: No bitmap compositor on device for HTTP

- **WHEN** a LAN client subscribes to `GET /v1/camera/ai`
- **THEN** the device MUST emit SSE `inference` events
- **AND** MUST NOT encode composited H.264 for that subscription
