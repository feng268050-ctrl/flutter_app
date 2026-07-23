## Requirements

### Requirement: Process video AI replay endpoint returns existing full result JSON

The system SHALL expose **`GET /v1/videos/:video_id/ai/replay`** on the embedded local HTTP server. If a complete, pre-existing inference result is available for the requested `video_id`, the endpoint SHALL return HTTP **200** with **`Content-Type: application/json`** and a **standard `ApiResult` JSON envelope**, where `data` is a single JSON document representing the full recorded-video inference result.

The endpoint SHALL be **read-only**: it MUST NOT start inference, MUST NOT create/restart `ProcessVideoAiSession`, and MUST NOT invalidate or regenerate any cached artifacts.

#### Scenario: Replay available for a known video

- **WHEN** a client requests `GET /v1/videos/V/ai/replay` and the device has an existing complete inference result for video `V`
- **THEN** the response MUST be HTTP 200
- **AND** `Content-Type` MUST be `application/json`
- **AND** the response body MUST be a standard `ApiResult` JSON object
- **AND** the `data` field MUST be a JSON object containing at least `videoId` equal to `V`

#### Scenario: Replay does not trigger inference

- **WHEN** a client requests `GET /v1/videos/V/ai/replay`
- **THEN** the device MUST NOT start a new offline/process-video inference job as a side effect
- **AND** MUST NOT create a new `ProcessVideoAiSession` solely to satisfy the request

### Requirement: Replay endpoint returns 404 when no existing result is present

If there is no existing complete inference result for the requested `video_id`, the system SHALL return HTTP **404**.

#### Scenario: No precomputed result

- **WHEN** a client requests `GET /v1/videos/V/ai/replay` and no complete inference result artifact exists for `V`
- **THEN** the response MUST be HTTP 404

### Requirement: Replay response JSON is versioned and frame-addressable

When returning a replay response, the JSON document SHALL be versioned and provide a frame-addressable timeline for recorded-video playback. The response SHALL include:

- `version` (string, required)
- `videoId` (string, required)
- `generatedAtMs` (number, required)
- `frames` (array, required) where each element uses the **same inference field set as SSE** (`timestampMs`, `success`, `code`, `level`, `status`, `message`, `imageWidth`, `imageHeight`, `boxes`, `source`); **`timestampMs`** is the source media timeline position in milliseconds

#### Scenario: Client replays by timestampMs

- **WHEN** the device returns replay JSON for video `V`
- **THEN** the `frames` array MUST allow a client to select the best entry for a given playback time using `timestampMs`
- **AND** each frame entry MUST include unified inference status and boxes fields suitable for overlay rendering
