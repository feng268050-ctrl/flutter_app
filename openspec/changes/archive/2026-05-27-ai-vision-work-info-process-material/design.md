## Context

`AiVisionFragment` shows a left **Work Information** card (`fragment_ai_vision.xml`). Today:

- The first value row label is **Detection Type** but the value `TextView` is statically bound to `@string/lens_text` (not wired in code).
- The second row is **Work Mode** with `tv_work_mode_value`; on video select it shows `ModelConstant.convertToText(processType)` only; `materialType` is never shown. `applyWorkModeFromLastTopModeContext()` (top quick/engineer mode + end-of-work model) exists but is unused.
- Live RTSP preview does not refresh work-info from current process state.
- Empty/missing values use `unknown_text`, empty string, or legacy defaults—not a consistent **`-`** placeholder.
- Button `ai_vision_choose_btn` and prompt `ai_vision_select_video_first` use “Choose” wording.

The app already maintains a real-time in-memory process-parameter snapshot via `ProcessParametersSnapshotStore` (updated from quick mode, engineer mode, and remote library mutations). Process recordings persist `processType`, `materialType`, and optional `processParametersJson` on `ProcessParamsVideo` rows; `ProcessVideoDetailsViewModel` defines the preferred resolution order for display labels.

## Goals / Non-Goals

**Goals:**

- Show **Process Type** and **Material Type** with the same localized enum labels used on process-video detail / engineer screens.
- Populate from video metadata when a recording is selected; from `ProcessParametersSnapshotStore` when live RTSP detection overlay is active.
- Use **`-`** when a field cannot be resolved.
- Align EN copy: **Select Video** button, **Select** in player prompts (zh equivalents updated consistently).

**Non-Goals:**

- Changing RTSP/inference/SSE behavior, recording-time metadata capture, or `ProcessParametersSnapshotStore` write paths.
- Replacing **Recording Time** row or lens-guard overlay logic.
- New HTTP/API surface.

## Decisions

### 1. Single refresh entry point in `AiVisionFragment`

Add `refreshWorkInformationPanel()` called from:

- `initView` / `clearAiVisionInfoValues` (both rows `-` or cleared state),
- `applySelectedProcessVideo` / `presentIdleStateForSelectedVideo`,
- Live RTSP active transitions (`scheduleAiFrameSampling` / `stopPreview` / `onResume` when `isLiveRtspOverlayActive()`),
- Optional periodic hook on resume if snapshot may have changed while fragment was paused (refresh once on resume when live).

**Rationale:** Avoids duplicating bind logic; supersedes dead `applyWorkModeFromLastTopModeContext()`.

**Alternative:** Separate ViewModel—rejected as overkill for two read-only labels.

### 2. Resolution order for recorded video

Mirror `ProcessVideoDetailsViewModel`:

1. Parse `processParametersJson` → `ProcessParametersData`; if present, use `processType` / `materialType` (and custom material name via existing helpers).
2. Else fall back to row `processType` / `materialType` columns on `ProcessParamsVideoVo`.
3. Per-field: if still null/undefined enum → display **`-`**.

Process type text: `ModelConstant.convertToText(Integer)` but map unknown/null to **`-`** instead of `unknown_text` for this panel only (wrapper or explicit null check).

Material type text: reuse `EngineerWashConvert.convertCleaningMaterialsText` + `MaterialDisplayNameUtils.localizeKnownMaterialName` for custom materials (same as video list/detail).

### 3. Live RTSP source

When `isLiveRtspOverlayActive()` (or broader: `LIVE_RTSP_PULL_ENABLED && isActive && live stream displayed`—match product intent: “页面开启实时 RTSP 检测”), read `ProcessParametersSnapshotStore.getSnapshot()`:

- `processType` → `ModelConstant.convertToText` or `-`
- `materialType` → material label helper or `-`

If a selected video is also loaded, **live snapshot takes precedence** while RTSP detection UI is active (operator sees current machine context, not stale file metadata).

**Alternative:** Always show video metadata when selected—rejected; user explicitly asked for snapshot during live RTSP.

### 4. Layout and string resources

- Add `@+id/tv_process_type_value` and `@+id/tv_material_type_value` (or repurpose `tv_work_mode_value` for material and add process type id).
- Replace label strings: new keys `process_type_text` / `material_type_text` (or rename existing `detection_type_text` / `work_mode_text` in place).
- Remove hardcoded `lens_text` from detection-type value row.
- `ai_vision_choose_btn` → “Select Video”; `ai_vision_select_video_first` → “Please select a video to detect.” (and zh).

### 5. Extract small pure helper (optional, testable)

`AiVisionWorkInfoLabels.resolve(ProcessParamsVideoVo, ProcessParametersData snapshot)` returning two display strings with `-` defaults—unit tested without Fragment.

## Risks / Trade-offs

- **[Risk] Snapshot empty on cold start** → Show `-` until quick/engineer mode publishes; acceptable per requirement.
- **[Risk] Stale snapshot after mode switch without publish** → Refresh on `onResume` when live; existing store updates on parameter edits mitigate.
- **[Risk] Legacy videos lack `materialType` column** → JSON or `-`; no migration in this change.

## Migration Plan

Ship in app release only; no server migration. Remove unused `applyWorkModeFromLastTopModeContext` and obsolete CacheKey comments referencing “Work Mode snapshot” if no other callers.

## Open Questions

- None blocking: live precedence over selected video while RTSP active is assumed from user wording.
