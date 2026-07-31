## Purpose

On-device Monitor AI Vision tab aligned with lws-ui `AiVisionFragment` chrome and selected-video state machine (without composited H.264 export).

## Requirements

### Requirement: AI Vision live preview

When the AI Vision tab is visible with no selected process video, the UI SHALL show PR0 live preview via `IpCameraPreview` and MUST NOT show the `liveVideoFailed` stub as the sole content.

#### Scenario: Live preview shown

- **WHEN** the user opens the AI Vision tab without a selected video
- **THEN** a PR0 preview surface MUST be visible

### Requirement: Live detect holder

While AI Vision live preview is active and lens contamination assist is enabled, the system SHALL run StreamDetect with `sessionSource: ai_vision_live` unless the weld holder is already running. Weld `live_stain_detect` MUST take priority. Leaving the AI Vision tab (Monitor IndexedStack not showing AI Vision) SHALL deactivate the live holder.

#### Scenario: Yield to weld

- **WHEN** weld StreamDetect is running
- **AND** AI Vision live would start
- **THEN** AI Vision MUST NOT start a conflicting StreamDetect session

### Requirement: Layout chrome

The left column SHALL show Work Info and only the Choose Video button. Detect, Replay, Re-detect, and play/pause controls SHALL overlay the right preview card (not the left column).

#### Scenario: Choose only on left

- **WHEN** a process video is selected
- **THEN** the left column MUST still expose Choose Video
- **AND** MUST NOT place Detect / Replay / Re-detect in the left column

### Requirement: Selected-video UI mode

The tab SHALL implement modes equivalent to lws-ui `SelectedVideoUiMode`: live (no selection), idle ready to detect (cover + Detect), idle detection complete (cover + Replay/Re-detect), and playback (source video + overlay). Detect/Replay completion MUST transition to idle detection complete (Detect MUST NOT remain stuck analyzing).

#### Scenario: Detect ends to complete

- **WHEN** Detect finishes (session playback ended / finalized)
- **THEN** the UI MUST show Replay and Re-detect
- **AND** MUST clear the analyzing overlay

### Requirement: Choose-video page

Choosing a video SHALL open a dedicated route with a table (Recording Time / Work Mode / Material / Duration / Operations) and a Select action that returns a `ProcessVideoRecord`. Returning without selecting MUST leave the current selection unchanged.

#### Scenario: Select from table

- **WHEN** the user taps Select on a row
- **THEN** the choose page MUST pop that record
- **AND** the AI Vision tab MUST enter idle ready or idle complete based on persisted timeline presence

### Requirement: Overlay and recorded Detect

The AI Vision tab SHALL draw detection boxes + right-top HUD from live publisher or process-video session samples. Choosing a process video SHALL show metadata (process type, material, create time). Detect SHALL start/reuse `ProcessVideoAiSession` with UI holder; Replay SHALL load timeline frames; Re-detect SHALL force-restart inference.

#### Scenario: Detect selected video on device

- **WHEN** the user selects a process video and presses Detect
- **AND** the AI daemon is ready
- **THEN** inference overlay updates MUST appear during the session

### Requirement: Live Work Info from process snapshot

When no process video is selected, Work Info process type and material SHALL come from `ProcessParametersSnapshotStore` when available; recording time MAY show unavailable. When a video is selected, fields SHALL come from that video row.

#### Scenario: Live snapshot labels

- **WHEN** live mode is active and a process snapshot exists
- **THEN** process type and material MUST reflect the snapshot

### Requirement: Home entry

The Home AI Vision quick action SHALL navigate to Monitor with the AI Vision tab selected and MUST NOT show a coming-soon snackbar.

#### Scenario: Home opens AI Vision

- **WHEN** the user taps Home AI Vision
- **THEN** Monitor MUST open on the AI Vision tab
