## 1. Coordinator and strings

- [x] 1.1 Add `camera_record_another_thread_recording` to `values/strings.xml`, `values-zh/strings.xml`, and `values-en/strings.xml` (zh exactly **`另一个线程正在录制中`**)
- [x] 1.2 Add single-thread `ExecutorService` to `CameraRecordCoordinator` and route `applySwitch` / `applySwitchBlocking` / `runStartPreflight` worker work through it
- [x] 1.3 Replace idempotent `applyOn` early success with `Result.fail(409, "recording_in_progress", "on")` using localized message; add `PreflightFail.RECORDING_IN_PROGRESS` for UI `runStartPreflight` toast path
- [x] 1.4 Re-check `isRecordingActive()` on the serial thread immediately before `finishApplyOn` / `EasyPlayerClientManger.start()`

## 2. UI and HTTP surface

- [x] 2.1 Ensure `CameraController.checkAndStartRecord` shows conflict toast and does not call `startRecord()` when coordinator reports recording in progress
- [x] 2.2 Verify `DeviceLocalHttpServer` propagates `result.errorMessage` for `recording_in_progress` without change to success `data` shape
- [x] 2.3 Update `docs/network-api-reference.md`: remove idempotent duplicate-`on` note; add `recording_in_progress` / 409 row and checklist step for rejected duplicate start

## 3. Tests

- [x] 3.1 Add `CameraRecordCoordinatorExclusiveStartTest` (Robolectric or pure JVM): second `applyOn` while active → 409 + `recording_in_progress`, no double start
- [x] 3.2 Extend `DeviceLocalHttpCameraRecordRouteTest` or coordinator test for failure JSON shape when already recording (mock/stub coordinator if needed)

## 4. Cleanup

- [x] 4.1 Archive or delete draft change `camera-record-single-thread-timeline` if no longer needed to avoid conflicting implementation notes
