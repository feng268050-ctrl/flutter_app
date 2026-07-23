## MODIFIED Requirements

### Requirement: Inference event payload

The system SHALL emit **`event: running`** for each completed stain-detect sample. The `data` line SHALL be a single JSON object containing at minimum:

- **`timestampMs`** (number, required): per-route clock semantics (see **Per-route timestampMs clock**).
- **`sessionId`** (string, optional): correlates with the current `start` epoch.
- **`success`**, **`code`**, **`level`**, **`status`**, **`message`**.
- **`imageWidth`**, **`imageHeight`** (numbers).
- **`boxes`**: array with **`x1`**, **`y1`**, **`x2`**, **`y2`**, **`classId`**, **`label`**, **`score`**.
- **`source`**: **`live_stain_detect`** or **`offline_stain_detect`** on `running` rows (from `StainDetectSource` / `AiStainDetectResult.source`).

The system MUST NOT emit a separate top-level `stainDetect` object on `running` rows; boxes and status live in the unified payload produced by `AiInferenceSseJson.runningData`.

#### Scenario: Client parses one running event

- **WHEN** the device completes an OpenCV stain detect sample and pushes to SSE
- **THEN** subscribers MUST receive `event: running` with JSON `data` containing `timestampMs`, `source`, and `boxes` when detection succeeded

### Requirement: Shared start payload

The `data` line for **`event: start`** on both routes SHALL be a JSON object with:

- **`sessionId`** (string, required)
- **`timestampMs`** (number, required)
- **`source`** (string, required): one of **`live_stain_detect`**, **`offline_stain_detect`**, or **`ai_vision_live`**
- **`samplingIntervalMs`** (number, required): **`2000`** for live weld; **`500`** for AI Vision live; **`200`** for process video
- **`imageWidth`**, **`imageHeight`** (numbers, optional)

#### Scenario: Process video start source and interval

- **WHEN** `ProcessVideoAiSession` begins for a valid recording
- **THEN** `start` `data.source` MUST be `offline_stain_detect`
- **AND** `samplingIntervalMs` MUST be `200`

#### Scenario: Live weld start source

- **WHEN** `LivePr1InferenceStreamClient` starts with SSE subscribers
- **THEN** `start` `data.source` MUST be `live_stain_detect`
- **AND** `samplingIntervalMs` MUST be `2000`

#### Scenario: AI Vision live start source

- **WHEN** AI Vision live preview begins SSE publishing
- **THEN** `start` `data.source` MUST be `ai_vision_live`
- **AND** `samplingIntervalMs` MUST be `500`
