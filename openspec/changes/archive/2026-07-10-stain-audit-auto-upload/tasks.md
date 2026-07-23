## 1. Native — per-frame output & failure image

- [x] 1.1 In `detect_runner::runLensDetIfEnabled`, create per-frame output subdirectory under session `output_dir` (e.g. `frame_<frame_id>/` or timestamp-based) and pass it to `analyzeOpencvStainDetectBgr`
- [x] 1.2 In `analyzeOpencvStainDetectBgr`, on `kDetectFailed` (`code == -3`) paths, write BGR input to `input_frame.jpg` and append path to `written_files` in the result / summary JSON
- [x] 1.3 Ensure `kFrameRejected` (`code == -5`) does **not** write `input_frame.jpg` for upload purposes
- [x] 1.4 Verify `summaryToJson` exposes `written_files` so Java can resolve `input_frame.jpg` without hard-coded paths

## 2. Java — audit model & stat payload

- [x] 2.1 Add `StainAuditStatus` enum (`CLEAN`, `STAIN_CONFIRMED`, `INTERNAL_FILTERED`, `DETECT_FAILED`, `AUTO_SUSPECTED_MISS`, `AUTO_SUSPECTED_FALSE_POSITIVE`)
- [x] 2.2 Add `StainAuditStat` POJO + mapper from `OpencvStainDetectResult` / `StreamDetectEvent.DetectResult` (V1 fields: `status`, `reason`, `source`, `primary_result`, `created_at`, optional `frame_id`, `code`)
- [x] 2.3 Add `StainAuditStatusMapper` mapping Live weld results: `code=-3` → `DETECT_FAILED`, `code=-5` → `INTERNAL_FILTERED`, `ok && code==0` → `STAIN_CONFIRMED` / `CLEAN` as appropriate; only `DETECT_FAILED` returns upload-eligible

## 3. Java — upload enqueue wiring (Live weld only)

- [x] 3.1 Add `StainAuditUploadCoordinator` (or extend `AiUploadFailureSampleHook`) with `maybeEnqueueLiveDetectFailed(Context, StreamDetectEvent.DetectResult, OpencvStainDetectResult, File inputFrame)` calling `AiUploadCoordinator.enqueue(LENS, type=0, image, statJson)`
- [x] 3.2 Resolve `input_frame.jpg` from native `written_files` / summary JSON; skip enqueue with warning if missing
- [x] 3.3 Wire into `OpencvStainDetectCoordinator.applyLiveWeldResult` after parsing mapper result, gated by `isLensContaminationDetectionEnabled()` and `LiveInferGraceCoordinator.isLiveInferActive()`
- [x] 3.4 Ensure enqueue runs off hot path if file copy is heavy (use existing coordinator background pattern or inline if copy is acceptable)

## 4. Unit tests

- [x] 4.1 `StainAuditStatusMapperTest`: `-3` → upload eligible; `-5` / `ok` → not eligible
- [x] 4.2 `StainAuditStatTest` or serializer test: required V1 JSON fields present
- [x] 4.3 `OpencvStainDetectCoordinator` test (or dedicated upload coordinator test): mock failure result triggers enqueue; frame rejected does not
- [x] 4.4 Native smoke or JNI test (if feasible): `-3` path produces `input_frame.jpg` in per-frame dir

## 5. Integration & verification

- [ ] 5.1 Device/emulator: force or mock `lens_det` `code=-3` on Live weld path; confirm `files/ai_upload/yyyy/mm/dd/lens/tasks/<uuid>/` contains `image.jpg`, `metadata.json`, `stat.json` with `status=DETECT_FAILED`
- [ ] 5.2 Confirm `code=-5` (e.g. overexposed) does **not** create upload task
- [ ] 5.3 Confirm `AiUploadDrainWorker` drains task when API base pinned (instrumented test or staging Worker)
- [ ] 5.4 Regression: L001 alert, consecutive OK gate, burst mode unchanged on live weld

## 6. Follow-up backlog (out of V1 — do not implement in this change)

- [ ] 6.1 `LensStainClusterGuard` temporal cluster tracking per `docs/Automated saving and uploading.md` §4–6
- [ ] 6.2 `AUTO_SUSPECTED_MISS` / `AUTO_SUSPECTED_FALSE_POSITIVE` enqueue + cluster fields in `stat.json`
- [ ] 6.3 Process Video offline path audit (if product expands scope)
- [ ] 6.4 Optional periodic queue scan (15–30 min) if WorkManager drain proves insufficient for backlog
