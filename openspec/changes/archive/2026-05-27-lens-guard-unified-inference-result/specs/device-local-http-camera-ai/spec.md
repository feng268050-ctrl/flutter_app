## ADDED Requirements

### Requirement: Production composited output is subscriber-gated

For Quick Mode and Engineer Mode production inference (`ProductionInferenceStreamClient`), `CameraAiHttpPublisher` SHALL start or continue composited encode (boxes and status burned into PR1 bitmaps) **only when** at least one active `GET /v1/camera/ai` subscriber exists. With zero subscribers, the publisher MUST NOT produce composited H.264/TS from production hold-forward results.

#### Scenario: Subscriber connects during weld

- **WHEN** laser is ON, production PR1 is streaming, and the first `/v1/camera/ai` client connects
- **THEN** composited mode MUST begin encoding frames with burned-in overlay from hold-forward unified results

#### Scenario: No subscribers during weld

- **WHEN** laser is ON and production inference runs but no `/v1/camera/ai` client is connected
- **THEN** the HTTP publisher MUST remain in pass-through or idle compositor state without burning production overlay into an output stream

### Requirement: HTTP camera AI encodes pre-composited live frames

When `GET /v1/camera/ai` is in `composited` mode driven by AI Vision live preview, the publisher SHALL encode H.264/TS from **pre-composited bitmaps** (camera frame with boxes already drawn via the shared frame compositor), not from pass-through RTSP with a second canvas overlay pass. Encoding MUST NOT block on unified infer completion.

#### Scenario: Compositor tick during in-flight infer

- **WHEN** the compositor encodes while live `inferFromI420` is in flight
- **THEN** it MUST encode the latest composited bitmap that used the last completed hold-forward result
- **AND** MUST deliver bytes without waiting for the in-flight infer

#### Scenario: Compositor matches on-device composited pixels

- **WHEN** a new live sample completes and hold-forward updates
- **THEN** subsequent compositor input bitmaps MUST include the new box coordinates baked into pixels
- **AND** MUST match what the operator sees on the live preview surface (no stacked overlay divergence)
