# 子码流实时污点检测 — 台架验收

与 OpenSpec 变更 `substream-realtime-stain-rules` 配套。功能与调用详见 [`SUBSTREAM_REALTIME_FEATURE_AND_API.md`](SUBSTREAM_REALTIME_FEATURE_AND_API.md)（**2026-05-25**）。算法规则见 [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) §5；职责见 §7。

## 前置

- `libai.so` 含 `nativePushFrame`、`nativeSetLaserOn`、`nativeSetAiVisionPreviewDetectionEnabled`（`scripts/verify_libai_jni.sh`）。
- App 持续向引擎推 **1920×1080 I420** 子码流（与产线标定一致）。
- 设备 `files/lens_guard/config.yaml` 与 zip 内 `assets/config.yaml` 一致。

## 手动步骤

1. **启动**：`nativeCreate` → `nativeSetListener` → `nativeStart`；确认 logcat `Stain mask center (885, 430) radius 280`（@1920×1080）。
2. **预览 det**：真实激光 OFF（App 侧判定）→ `nativeSetLaserOn(false)` → 进入 AI Vision → `nativeSetAiVisionPreviewDetectionEnabled(true)`。
3. **日志**：预览开启后，**每收到一帧**子码流应有 `Preview-Det` 结果（与 App `nativePushFrame` 节奏一致）；native **不再**用 `substream_infer_interval_sec` 节流预览。例：App 约每 200ms / 500ms 推一帧，则 logcat 频率与之相当。`onCheckResult` 的 `message` 可解析 JSON，`source=preview_det`，含 `level` 与 `boxes[]`。
4. **Overlay**：框坐标与当前推帧分辨率 1:1，勿在 App 再乘 700/640 或 letterbox。
5. **无生产 LOCKED**：预览路径下勿因 `preview_det` 的 `level=2` 单独触发产线 LOCKED（生产周期/焊后路径仍可按 §5 行为）。
6. **生产路径**：激光 OFF 后焊后/周期 `onCheckResult` 仍为文本 `level/status/message`（非 JSON），等级语义与改前一致。
7. **分辨率变更（可选）**：切换子码流宽高后，logcat 应出现 `re-init stain level rules`。

## 不在此验收范围

- `nativeInferVideoAndSave`：仅带框 MP4，无 `onCheckResult`、无窗口 level。
