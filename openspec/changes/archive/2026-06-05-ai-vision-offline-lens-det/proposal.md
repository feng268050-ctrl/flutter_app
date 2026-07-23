## Why

原计划为工艺视频离线增加 **zero_point** one-shot，但产品/工程确认：AI Vision 离线应对齐 **OpenCV `lens_det`**（与 RKNN 污点并列），**不**在工艺视频路径调用 `zero_point` native。`inferLensDetFromI420` 与 `ProcessVideoAiSession` 500ms 抽帧已部分接入（`ENABLE_LENS_DET_APP`），尚缺 **时间轴持久化、SSE 字段、默认可验收开关** 等，需在本变更收口。

**zero_point** 仍仅用于激光 ON 生产任务（`ZeroPointDetectCoordinator`），本变更 **不** 扩展 zero_point 离线。

## What Changes

- **保持** `MediaMetadataRetriever` + **`AI_VISION_PROCESS_VIDEO` 500ms** 网格不变；每采样 **一帧 I420 → 一次** `inferLensDetFromI420`（已实现，本变更补全可观测性与持久化）。
- **不新增** `inferZeroPointFromI420` / 工艺视频 `zpHandle` / timeline `zeroPoint` 字段。
- 工艺视频 **lens_det** 样本写入 **timeline JSON** 与 **`running` SSE**（`targetX`/`targetY`/`ok`/`code`）。
- **不** 写 Modbus / `zeroPointCorrection`（lens_det 仅检测与展示；与 zero_point 生产校正无关）。
- 验收：AI Vision Detect + 可选 `ENABLE_LENS_DET_APP=true` 构建；logcat `process_video_lens_det`。

## Capabilities

### New Capabilities

- `ai-vision-offline-lens-det-detect`: 工艺视频离线 lens_det 时间轴/SSE/持久化与 overlay 数据通路（500ms 不变，one-shot 不变）。

### Modified Capabilities

- `ai-vision-recorded-video-realtime`: 明确 Detect 会话在 RKNN 之外 **必须** 可记录 lens_det 样本（不仅内存列表）。
- `device-local-http-video-ai`: `running` SSE 增加 `lensDet` 可选字段（与 stain 并列）。

### Removed / Out of Scope (relative to draft zero_point offline)

- `zero-point-app-one-shot-inference`（工艺视频）：**取消**
- `ai-vision-offline-zero-point-detect`：**取消**（由 `ai-vision-offline-lens-det-detect` 替代）

## Impact

- **Java**: `ProcessVideoAiSession`, `ProcessVideoAiTimeline` / `ProcessVideoAiTimelinePersistence`, `AiInferenceSseJson`, `AiVisionFragment`（overlay 已有，对齐持久化）。
- **复用**: `AiManager.inferLensDetFromI420`, `LensDetDetectResult`, `nativeOpencvStainDetectFromI420`（RKNN `handle` + `config.yaml` `lens_det:`）。
- **Native**: 无 API 变更。
- **构建**: `ENABLE_LENS_DET_APP=true` 用于验收（`local.properties` 或 `-P`）。
- **部署**: `make sync`。
