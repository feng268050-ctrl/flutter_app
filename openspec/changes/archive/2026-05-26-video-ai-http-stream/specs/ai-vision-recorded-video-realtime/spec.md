## ADDED Requirements

### Requirement: Selected process video uses composited preview (same pipeline as HTTP)

When the user starts **Detect** on a process video in AI Vision, the system SHALL start **`ProcessVideoAiSession`** with an internal **1× playback clock** (source decoded inside the session only). The in-app preview MUST display the **composited H.264** output from the same encoder fan-out as **`GET /v1/videos/:video_id/ai`**, decoded to `PlayerView` via **`ProcessVideoAiCompositedPreview`**. The system MUST NOT show source MP4 + `DetectionOverlayView` during an active session. Inference SHALL use **`AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO`** (**200 ms**). Camera live preview remains **`AI_VISION_LIVE`** (500 ms).

The system MUST NOT require completion of whole-file batch offline analysis before showing composited preview. The legacy flow that pauses playback with a full-file progress bar until `buildOfflineInferenceTimeline` or `nativeInferVideoAndSave` completes MUST NOT remain the default behavior.

#### Scenario: User starts detect

- **WHEN** the user taps **Detect** on a valid process video
- **THEN** composited preview MUST begin as soon as the first decodable access units are available
- **AND** LAN `ffplay` on `/v1/videos/<id>/ai` MUST show the same composited stream (same session fan-out)

#### Scenario: No overlay on source during session

- **WHEN** a `ProcessVideoAiSession` is active for the selected video
- **THEN** `DetectionOverlayView` MUST NOT be used to draw boxes on top of the source ExoPlayer item

### Requirement: Seek disabled during active session

While `ProcessVideoAiSession` is active, the selected-video player MUST NOT allow user seek or scrubbing (progress bar drag). Seek MAY be supported in a future change.

#### Scenario: User attempts to scrub

- **WHEN** a session is active and the user attempts to change playback position via the seek control
- **THEN** the player MUST ignore the seek or keep playback at the current position

### Requirement: No audio on recorded-video AI path

The selected-video player, inference MP4 mux, and HTTP fan-out for this session MUST use **video only** and MUST NOT mux or play audio tracks from the source recording.

#### Scenario: Source contains audio

- **WHEN** the source MP4 contains an audio track
- **THEN** AI Vision playback and the inference MP4 artifact MUST still be video-only

### Requirement: End-of-stream UI does not auto-play inference file

When the session playback clock reaches end-of-stream, the UI MUST keep the **last composited frame** visible until idle. The system MUST NOT automatically start ExoPlayer replay of the inference MP4. The user MUST be able to use **Replay** (plays finalized `.mp4`) or **Re-detect** via existing controls.

#### Scenario: Playback completes

- **WHEN** the session clock reaches EOS and `…mp4` rename succeeds
- **THEN** the preview MUST remain on the last composited frame (no auto replay)
- **AND** the user MAY tap **Replay** to play the finalized inference MP4 in ExoPlayer

### Requirement: Parallel inference MP4 capture with tmp finalize

While the session runs, the system SHALL encode composited frames into **`files/ai-vision-inference-videos/<owner>/ai-vision-inference-<owner>-<cacheKey>.mp4.tmp`**. On successful end-of-stream, the system SHALL atomically **rename** the tmp file to **`.mp4`**. If the session is cancelled or `force` re-infer is requested, the system SHALL delete the incomplete **`.tmp`** file and MUST NOT leave a truncated **`.mp4`** as the upload artifact.

#### Scenario: Successful completion

- **WHEN** playback reaches end-of-stream and mux finalize succeeds
- **THEN** a non-empty **`…mp4`** MUST exist at the canonical inference path and **`…mp4.tmp`** MUST NOT remain

#### Scenario: User forces re-infer

- **WHEN** the user triggers manual re-infer while a prior inference MP4 exists
- **THEN** the system MUST stop the current session, remove stale tmp/mp4 for that cache key, and start a new real-time session

### Requirement: Cache key unchanged

The session cache key SHALL remain **`AiVisionInferenceUploadStateStore.buildInferenceCacheKey(processVideo, sourceFile)`** (plus optional re-infer salt). Upload and HTTP session identity MUST use the same key as today.

#### Scenario: Library upgrade invalidates cache

- **WHEN** `aiVersion` in the cache key inputs changes
- **THEN** a new session MUST use a new cache key and MUST NOT reuse an old inference MP4 path

### Requirement: Upload uses finalized MP4 only

`AiVisionInferenceVideoUploadRunner` and upload button state SHALL treat the inference video as ready only when the finalized **`.mp4`** exists and is non-empty. Upload MUST NOT use **`.mp4.tmp`**.

#### Scenario: Upload during processing

- **WHEN** the user taps upload while the session is still running and only `.mp4.tmp` exists
- **THEN** the UI MUST indicate inference video is not ready (equivalent to existing «推理视频尚未准备好» semantics)

### Requirement: Session shared with HTTP

`ProcessVideoAiSession` SHALL be reference-counted so AI Vision UI and **`GET /v1/videos/:video_id/ai`** subscribers share one decode and one compositor. Tearing down the Fragment view while HTTP subscribers remain MUST NOT stop the session until the last subscriber releases.

#### Scenario: Leave AI Vision tab while HTTP client connected

- **WHEN** the user navigates away from AI Vision but a LAN HTTP client remains subscribed to `/v1/videos/<id>/ai`
- **THEN** the session MUST continue processing and streaming until the HTTP connection ends
