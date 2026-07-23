## ADDED Requirements

### Requirement: Process video inference runs on a background worker

`ProcessVideoAiSession` SHALL submit `LensGuardManager.inferFromJpg` on a session background executor. The composited encode / playback clock (15 fps tick, HTTP fan-out, `ProcessVideoAiCompositedPreview`) MUST NOT block waiting for JPG inference to complete.

#### Scenario: Encode continues while infer is in flight

- **WHEN** the session playback clock advances to encode position `P` and the latest scheduled sample at `T` (`T <= P`) is still inferring on the worker
- **THEN** the session MUST still mux/composite and deliver the video frame for `P` without stalling the clock
- **AND** MUST NOT call `inferFromJpg` synchronously on the encode worker thread

### Requirement: Process video uses inferFromJpg and unified results

When a new sample is scheduled at source time `T` (per `AI_VISION_PROCESS_VIDEO` interval), the session SHALL extract a JPEG, call `inferFromJpg` asynchronously, and on completion append a timeline entry built from `LensGuardInferenceResult` (`level`, `status`, `message`, `boxes`, dimensions).

#### Scenario: Sample completes

- **WHEN** `inferFromJpg` returns `success` for sample time `T`
- **THEN** the session MUST store the unified result at `T` in the session timeline
- **AND** subsequent composited frames MUST be eligible to use that result’s overlay geometry

### Requirement: Hold-forward overlay until the next sample result

Compositing for encode position `P` SHALL use the **latest completed** sample with `sampleTimeMs <= P` (same semantics as `ProcessVideoAiTimeline.findFrameAt`). Overlay boxes (`level`, `status`, `message`, detection rectangles) from that sample MUST be drawn on `P` and on all later frames until a **newer** completed sample exists, at which point compositing for positions `>=` that newer sample time MUST switch to the newer boxes.

#### Scenario: Result arrives after playback has moved on

- **WHEN** sample at `T=200` ms completes after the clock has already encoded frames at 266 ms and 333 ms using an older sample (or no boxes)
- **THEN** frames at 200 ms and later MUST use the 200 ms result once it is stored
- **AND** frames already muxed before the result arrived MAY remain as-is; frames from the next encode tick onward MUST reflect the updated hold-forward overlay

#### Scenario: New sample updates overlay for following frames only

- **WHEN** sample at `T=400` ms completes while sample `T=200` ms was previously active for hold-forward
- **THEN** compositing for positions `P >= 400` ms MUST use the 400 ms boxes
- **AND** positions `P` in `[200, 400)` MUST have used 200 ms boxes (historical mux) or be recomposed only if the implementation supports rewind (not required in v1)

#### Scenario: Before first result

- **WHEN** playback starts and no sample has completed yet
- **THEN** composited output MAY be source video only (no detection overlay)
- **AND** the playback clock MUST still advance

### Requirement: Process video drops overlapping sample infer without blocking encode

While a prior `inferFromJpg` is in flight (session or global unified in-flight policy), the session MUST NOT start another `inferFromJpg` for a newer sample time. The encode path MUST continue using the previous hold-forward overlay.

#### Scenario: Busy skips new sample but video keeps playing

- **WHEN** the 200 ms sampling gate fires at `T=600` ms but unified infer is still processing `T=400` ms
- **THEN** the session MUST NOT enqueue infer for 600 ms until the in-flight call completes
- **AND** compositing at 600 ms and onward MUST still use the latest completed sample strictly before 600 ms (e.g. 400 ms once available, else 200 ms)

### Requirement: Overlay uses unified level status and box coordinates

Hold-forward compositing MUST read `level`, `status`, `message`, and `boxes` from `LensGuardInferenceResult` (via timeline adapter), not from raw JSON, stacked overlay views, or separate status `TextView` widgets during an active composited detect session.

#### Scenario: Boxes and status drawn on composited bitmap

- **WHEN** hold-forward selects sample `T` for encode position `P`
- **THEN** the shared frame compositor MUST draw detection rectangles and status text derived from that result’s `level`, `status`, and `message` into the encode bitmap
- **AND** HTTP `/v1/videos/:id/ai` subscribers MUST receive the same composited pixels as in-app preview
- **AND** `tvAiResult` / `tvAiState` MUST NOT be the on-screen source of stain status during composited playback
