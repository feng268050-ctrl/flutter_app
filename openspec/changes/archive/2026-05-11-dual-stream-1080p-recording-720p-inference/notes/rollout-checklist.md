# Rollout checklist & rollback (task 5.3)

## Preconditions

- IPC: main stream tuned for recording quality; sub-stream tuned for latency (see `docs/dual-stream-workflow.md`).
- App: `PR0` / `PR1` paths verified on target cameras.

## Release gates

- [ ] AI Vision sub-first works on reference hardware.
- [ ] Fallback to main logged and tested once per release candidate.
- [ ] Recording smoke test on main stream (resolution acceptable).

## Rollback options (no reinstall)

| Goal | Action |
|------|--------|
| Live sub → main fallback | Fixed in code: `AiVisionFragment` candidates `LIVE_INFERENCE_RTSP_URL` then `CAMERA_RTSP_MAIN_URL` |
| RTSP paths | Fixed constants `CAMERA_RTSP_MAIN_PATH` `/PR0`, `CAMERA_RTSP_SUB_PATH` `/PR1` (not Dev-editable) |
| Wrong paths | Dev → edit RTSP main/sub paths → Save |

Camera IP/paths are compile-time constants in `CameraConfig`; clearing app data does not change them.

## Kill-switch code defaults

- Live fallback: **sub then main** (hard-coded candidate list in `AiVisionFragment`).
- 640×640 等模型输入变换在 **AI native 库**内完成，Java 端不做 letterbox。
