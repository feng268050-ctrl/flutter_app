# ai-vision-recorded-video-realtime Specification

## Purpose

Real-time AI Vision **Detect** on selected process videos: ExoPlayer plays the source recording while `ProcessVideoAiSession` samples frames for OpenCV stain detect, builds a timeline, and fans out SSE to LAN clients—matching the HTTP split of `GET /v1/videos/:video_id/stream` + `GET /v1/videos/:video_id/ai`.
## Requirements
### Requirement: Selected process video separates playback from detect sampling

When the user starts **Detect** on a process video in AI Vision, the system SHALL:

1. Start **`ProcessVideoAiSession`** for timeline sampling, SSE fan-out, and optional HTTP subscribers.
2. Start **ExoPlayer** playback of the **source recording** immediately (same media as `GET /v1/videos/:video_id/stream`).
3. Render detection overlays on **`DetectionOverlayView`** above the player using **`ProcessVideoAiTimeline.findFrameAt(playbackPositionMs)`** for status/HUD and **`findLastFrameWithDetectionAt(playbackPositionMs)`** for boxes (hold-forward), where **`playbackPositionMs`** is the **ExoPlayer** current position during active Detect and Replay.

The system MUST NOT show a static cover-only preview in place of video playback during an active Detect session. The system MUST NOT mux or display composited H.264 from an on-device encoder for preview. LAN clients MUST receive detect events via **`GET /v1/videos/:video_id/ai`** SSE (`running` events), not composited video bytes.

Sampling interval SHALL follow **`AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO`** (200 ms in code). Camera live preview remains **`AI_VISION_LIVE`** (500 ms).

The system MUST NOT require whole-file batch analysis before showing playback with overlays.

#### Scenario: User starts detect

- **WHEN** the user taps **Detect** on a valid process video
- **THEN** ExoPlayer MUST begin playing the source recording promptly
- **AND** `ProcessVideoAiSession` MUST sample frames on a background worker independently of the decoder
- **AND** overlays MUST update as timeline samples complete and as playback position advances
- **AND** LAN SSE on `/v1/videos/<id>/ai` MUST emit matching `running` events with media-timeline `timestampMs`

#### Scenario: No server composited preview player

- **WHEN** a `ProcessVideoAiSession` is active
- **THEN** `ProcessVideoAiCompositedPreview` MUST NOT be used
- **AND** the system MUST NOT mux composited H.264 solely for on-screen display

### Requirement: Overlay maps detect frame coordinates to video display bounds

When drawing boxes on `DetectionOverlayView` for recorded-video Detect or Replay, the system SHALL map box coordinates from the **detect/sample frame** (`imageWidth` × `imageHeight` on the timeline entry, which MAY be lower resolution than the source video) into **view space** using:

1. **`AiDetectOverlayGeometry.toNormalizedRect`** — pixel xyxy on the detect frame → normalized [0,1].
2. **`AiDetectOverlayGeometry.computeFitCenterContentRect`** — source video display aspect (from ExoPlayer video format or timeline/metadata) fit-center inside the overlay view.
3. **`DetectionOverlayView.setVideoContentRect`** — apply normalized boxes within the content rect (letterboxing), not the full view.

#### Scenario: Detect frame smaller than source video

- **WHEN** timeline `imageWidth`/`imageHeight` are 640×360 and the source video displays as 1920×1080 letterboxed in the player
- **THEN** box corners MUST align with the corresponding region on the visible video frame
- **AND** MUST NOT stretch boxes to the full overlay view ignoring letterbox margins

#### Scenario: Replay uses same mapping as Detect

- **WHEN** the user taps **Replay** after Detect completes
- **THEN** overlay mapping MUST use the same geometry rules as during Detect

### Requirement: Seek disabled during active session

While `ProcessVideoAiSession` is active, the selected-video ExoPlayer MUST NOT allow user seek or scrubbing. Seek MAY be supported in a future change.

#### Scenario: User attempts to scrub

- **WHEN** a session is active and the user attempts to change playback position via the seek control
- **THEN** the player MUST ignore the seek or keep playback at the current position

### Requirement: No audio on recorded-video AI path

The selected-video ExoPlayer for process-video Detect and Replay MUST use **video only** and MUST NOT play audio tracks from the source recording.

#### Scenario: Source contains audio

- **WHEN** the source MP4 contains an audio track
- **THEN** AI Vision ExoPlayer playback MUST still be video-only (audio renderer disabled)

### Requirement: End-of-stream UI does not auto-replay

When ExoPlayer reaches end-of-stream during Detect, the UI MUST keep the **last video frame** visible (paused player or cover) until idle. The system MUST NOT automatically start a second playback loop. The user MUST be able to use **Replay** (source MP4 + timeline overlay) or **Re-detect** via existing controls.

#### Scenario: Playback completes

- **WHEN** Detect playback reaches EOS and the session finalizes the timeline
- **THEN** the UI MUST remain on the last frame without auto-replay
- **AND** the user MAY tap **Replay** to play the **source recording** again with timeline overlay

### Requirement: Cache key unchanged

The session cache key SHALL remain **`AiVisionInferenceUploadStateStore.buildInferenceCacheKey(processVideo, sourceFile)`** (plus optional re-infer salt). Upload and HTTP session identity MUST use the same key as today.

#### Scenario: Library upgrade invalidates cache

- **WHEN** `aiVersion` in the cache key inputs changes
- **THEN** a new session MUST use a new cache key and MUST NOT reuse stale timeline artifacts for a prior engine generation

### Requirement: Session shared with HTTP

`ProcessVideoAiSession` SHALL be reference-counted so AI Vision UI and **`GET /v1/videos/:video_id/ai`** subscribers share **one session** (one sampling pipeline, one timeline). Tearing down the Fragment view while HTTP subscribers remain MUST NOT stop the session until the last subscriber releases.

#### Scenario: Leave AI Vision tab while HTTP client connected

- **WHEN** the user navigates away from AI Vision but a LAN HTTP client remains subscribed to `/v1/videos/<id>/ai`
- **THEN** the session MUST continue sampling and emitting SSE until the HTTP connection ends

### Requirement: Process video detect runs on a background worker

`ProcessVideoAiSession` SHALL extract sample frames with **`MediaMetadataRetriever`**, convert to I420, and invoke **`AiManager.opencvStainDetectFromI420`** (when the OpenCV stain-detect session is active) on a **session background executor**. ExoPlayer playback and the session sample scheduler MUST NOT block waiting for detect to complete.

#### Scenario: Playback continues while detect is in flight

- **WHEN** ExoPlayer advances to position `P` and the latest scheduled sample at `T` (`T <= P`) is still detecting on the worker
- **THEN** ExoPlayer MUST continue without stalling
- **AND** overlay at `P` MUST use hold-forward from the latest **completed** timeline sample before `P`

### Requirement: Process video drops overlapping detect samples without blocking playback

While a prior OpenCV process-video detect call is in flight, the session MUST NOT start another detect for a newer sample time accepted by the same gate. ExoPlayer playback MUST continue; overlay uses hold-forward.

#### Scenario: Busy skips new sample but video keeps playing

- **WHEN** the process-video sampling gate fires at `T=600` ms but detect is still processing `T=400` ms
- **THEN** the session MUST NOT enqueue detect for 600 ms until the in-flight call completes or is dropped per gate policy
- **AND** overlay at 600 ms MUST use the latest completed sample strictly before 600 ms

### Requirement: Recorded detect uses client overlay from timeline

While `ProcessVideoAiSession` is active, display and LAN SSE MUST be **client-side only**: map timeline stain-detect results to overlay boxes and HUD text. ExoPlayer MUST NOT wait for detect completion.

Box coordinates for AI Vision overlay MUST use **`findFrameAt(playbackPositionMs)`** only: show boxes when that frame has detection; otherwise show no boxes. Status text SHALL reflect the latest completed sample at or before `P`.

After session finalization, when a temporal summary frame exists, overlay for completion and Replay MUST use the summary frame as specified in **Detect completion overlay uses temporal summary frame**.

#### Scenario: Overlay tracks playback position

- **WHEN** playback is at position `P` ms during **active** Detect and the latest completed sample at or before `P` has boxes
- **THEN** the overlay MUST show that sample's boxes on `DetectionOverlayView`
- **AND** ExoPlayer MUST continue without waiting for detect

#### Scenario: Sample at P has no box

- **WHEN** during **active** Detect the latest completed sample at or before `P` has no detection boxes
- **THEN** overlay at `P` MUST show no contamination boxes

#### Scenario: HTTP SSE matches timeline

- **WHEN** a sample at media position `T` ms completes
- **THEN** SSE MUST emit `running` with `timestampMs` `T`
- **AND** in-app overlay at position `T` during active Detect MUST use the same result fields

#### Scenario: Summary frame after session complete

- **WHEN** Detect session finalizes and temporal reduction appended a summary frame
- **THEN** SSE MUST have emitted a summary `running` before `stop`
- **AND** AI Vision completion overlay MUST match that summary frame

### Requirement: Recorded-video Status HUD is always visible

When a process video is selected in AI Vision, the top-right **Status** line on `DetectionOverlayView` MUST remain visible for the selected-video surface (cover or player).

- **WHEN** Detect and Replay are not active
- **THEN** the HUD MUST display **`Status: IDLE`**

- **WHEN** Detect or Replay is active
- **THEN** the HUD MUST update from the latest completed sample at or before playback position (e.g. `STAIN_DETECT`, level, or message fields)

#### Scenario: Video selected before Detect

- **WHEN** the user selects a process video and has not tapped **Detect**
- **THEN** `DetectionOverlayView` MUST show **`Status: IDLE`** in the top-right HUD

### Requirement: AI Vision recorded overlay does not hold-forward boxes

AI Vision process-video Detect and Replay overlay MUST NOT retain detection boxes from an earlier sample when the latest completed sample at or before playback position `P` has no boxes. Box display MUST reflect only:

1. The temporal summary frame after session finalization (per **Detect completion overlay uses temporal summary frame**), or
2. The timeline sample at or before `P` returned by `findFrameAt(P)` when that sample itself has detection boxes, or
3. No boxes when neither applies.

The system MUST NOT use `findLastFrameWithDetectionAt`, `findLastStainDetectWithTargetAt`, or equivalent hold-forward lookup for AI Vision overlay rendering.

#### Scenario: Later sample without box clears overlay during Detect

- **WHEN** sample at `T1` ms completed with boxes and sample at `T2` ms (`T2 > T1`, `T2 <= P`) completed without boxes during **active** Detect
- **THEN** overlay at position `P` MUST show no contamination boxes
- **AND** status text MUST still reflect sample `T2` (or the latest sample at or before `P`)

#### Scenario: Replay without summary does not hold-forward

- **WHEN** Replay runs on a timeline without a temporal summary frame
- **THEN** overlay MUST NOT show boxes from an earlier sample when the sample at `P` has no boxes

### Requirement: Detect completion overlay uses temporal summary frame

After `ProcessVideoAiSession` finalizes with temporal reduction, AI Vision recorded-video overlay for **Detect complete**, **Replay**, and idle cover with detection result MUST use the temporal summary frame boxes and status—not per-frame detections or hold-forward from earlier samples.

During an **active** Detect session (before finalization), overlay MUST show boxes only from the current timeline sample at `P` when that sample has detection boxes; otherwise MUST show no boxes.

#### Scenario: Replay after detect with fleeting false positives

- **WHEN** Detect completes and reduction removed all non-persistent boxes
- **THEN** Replay overlay MUST show no contamination boxes at any playback position

#### Scenario: Replay after detect with persistent contamination

- **WHEN** Detect completes and reduction kept persistent boxes
- **THEN** Replay overlay MUST show the summary boxes when playback reaches the summary timestamp or end-of-stream

