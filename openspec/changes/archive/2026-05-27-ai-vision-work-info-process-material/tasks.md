## 1. Layout and strings

- [x] 1.1 Update `fragment_ai_vision.xml`: Process Type / Material Type labels; add `tv_process_type_value` and `tv_material_type_value` (remove hardcoded `lens_text` value)
- [x] 1.2 Add or rename string keys in `values`, `values-en`, `values-zh` for process/material type labels
- [x] 1.3 Change `ai_vision_choose_btn` to “Select Video” (EN) and aligned zh; update `ai_vision_select_video_first` and any player “choose” copy to “select”

## 2. Work information resolution

- [x] 2.1 Add `AiVisionWorkInfoLabels` (or equivalent) to resolve process type and material type from `ProcessParamsVideoVo` / `ProcessParametersData` with `-` for missing values
- [x] 2.2 Add unit tests for JSON-first, column fallback, custom material name, and dash fallbacks

## 3. AiVisionFragment wiring

- [x] 3.1 Implement `refreshWorkInformationPanel()`; call from video select, clear, init, and idle/playback state changes
- [x] 3.2 When live RTSP detection is active, bind from `ProcessParametersSnapshotStore.getSnapshot()` (precedence over selected video)
- [x] 3.3 Refresh work info on `onResume` when live RTSP is active; remove unused `applyWorkModeFromLastTopModeContext`
- [x] 3.4 Manual: select video with/without `processParametersJson`; live RTSP with snapshot; empty states show `-`

## 4. Validation

- [x] 4.1 Run `openspec validate ai-vision-work-info-process-material --strict`
- [x] 4.2 Run targeted unit tests and assemble debug build
