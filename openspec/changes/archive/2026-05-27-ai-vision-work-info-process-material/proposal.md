## Why

The AI Vision left **Work Information** panel still labels and fills fields as **Detection Type** / **Work Mode** (including a hardcoded lens placeholder and top-mode work-mode fallbacks). Operators need the same **Process Type** and **Material Type** context they use elsewhere in the app, sourced from the selected recording or from live process-parameter state during RTSP detection.

## What Changes

- Rename panel row labels from **Detection Type** / **Work Mode** to **Process Type** / **Material Type** (localized).
- Display enum-backed human-readable text for both fields using the same converters as process-video and engineer/quick UIs (`ModelConstant`, material display helpers).
- **Recorded video selected**: resolve `processType` and `materialType` from `ProcessParamsVideo` row columns and/or parsed `processParametersJson`, with column fallbacks when JSON is absent.
- **Live RTSP detection active**: read `ProcessParametersSnapshotStore.getSnapshot()` for current process parameters and display their `processType` / `materialType`.
- When a value cannot be resolved, show **`-`** (not empty string or `unknown`).
- Update copy: info-panel button **Select Video**; player empty-state / prompt strings use **Select** instead of **choose** (EN; aligned zh strings).

## Capabilities

### New Capabilities

- `ai-vision-work-information`: Work Information panel labels, data sources, fallbacks, and related AI Vision copy for video selection prompts.

### Modified Capabilities

<!-- None: existing ai-vision-* specs do not define Work Information panel behavior. -->

## Impact

- **UI**: `fragment_ai_vision.xml`, `AiVisionFragment` (bind/refresh work-info rows on video select, clear, live RTSP start/stop/resume).
- **Strings**: `values`, `values-en`, `values-zh` (`detection_type_text` → process type label, `work_mode_text` → material type label, `ai_vision_choose_btn`, `ai_vision_select_video_first`, related choose→select copy).
- **Reuse**: `ProcessParametersSnapshotStore`, `ModelConstant`, `EngineerWashConvert` / `MaterialDisplayNameUtils` / `ProcessVideoDetailsViewModel` resolution patterns for material labels (including custom material names).
- **Tests**: unit tests for work-info resolution helper(s) if extracted.
