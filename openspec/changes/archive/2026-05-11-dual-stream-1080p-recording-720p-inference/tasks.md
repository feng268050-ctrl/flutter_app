## 1. Capability discovery & baseline

- [x] 1.1 Inventory camera stream capabilities (main/sub URLs, supported resolutions) and document tested IPC models.
- [x] 1.2 Capture baseline metrics with current single-stream policy: live stutter observations, first-frame time, decodeType, and recording quality.

## 2. Configuration model

- [x] 2.1 Extend `CameraConfig` to support profile-aware stream endpoints (main-recording profile and live-inference profile).
- [x] 2.2 Add fallback policy config for sub-stream unavailability and emit explicit fallback reason logs.

## 3. Runtime stream selection

- [x] 3.1 Update AI Vision live path to prefer sub-stream and log selected profile + effective `RESULT_VIDEO_SIZE` / `LIVE_VIDEO_SIZE` (IPC may output e.g. 640×512).
- [x] 3.2 Update recording path to bind 1080p profile when dual-stream is available.
- [x] 3.3 Implement deterministic fallback to single-stream policy when sub-stream connection/capability check fails.

## 4. Inference input handling

- [x] 4.1 Keep display/render aspect-ratio behavior independent from model input resize.
- [x] 4.2 Add optional 640x640 preprocessing mode for inference input only (letterbox/resize), without forcing camera output resolution.

## 5. Validation & rollout

- [x] 5.1 Validate dual-stream behavior on devices that support sub-stream and on devices that do not.
- [x] 5.2 Compare before/after motion stutter and latency metrics with IPC sub-stream configured (e.g. 640×512 reference); record regression findings.
- [x] 5.3 Prepare rollout checklist and rollback switch to return to legacy single-stream behavior if instability appears.
