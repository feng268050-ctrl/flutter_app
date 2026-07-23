## 1. Inference stream client

- [x] 1.1 Add production inference RTSP client (virtual Surface `EasyPlayerClient`, URL `CameraConfig.liveInferenceRtspUrl`) with start/stop and I420 → `LensGuardManager` callbacks
- [x] 1.2 Add lifecycle coordinator that starts inference stream on `DeviceStatus.isLaserOn()==true` and stops on laser OFF, with logs `reason=laser_on|laser_off` and profile `sub`
- [x] 1.3 Register coordinator in Quick Mode and Engineer Mode (enter/exit lifecycle); skip modes that hide camera float (e.g. CNC cut)

## 2. Decouple recording from inference

- [x] 2.1 Remove `LensGuardManager.onI420Frame` / `updateFrameSize` from `EasyPlayerClientManger` recording path (PR0 only)
- [x] 2.2 Verify `CameraController` record start/stop only affects `EasyPlayerClientManger` and logs `reason=record_start|record_stop` with profile `main`
- [x] 2.3 Verify laser ON + record ON: both clients active; stop record leaves PR1 running until laser OFF

## 3. Validation

- [x] 3.1 Manual matrix: Quick/Engineer × {laser on/off} × {record on/off} — confirm inference events only need laser for frame push
- [x] 3.2 Confirm AI Vision Tab live path unchanged (no duplicate PR1 session when not in production modes)
- [x] 3.3 Add or extend instrumented/log test for inference stream start on laser edge if feasible on device CI
