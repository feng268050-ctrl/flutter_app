## Context

- **工艺视频**：`ProcessVideoAiSession.runInferSample` 已在 `ENABLE_LENS_DET_APP` 时调用 `AiManager.inferLensDetFromI420(..., "process_video_lens_det")`，结果存于内存 `lensDetSamples`；`AiVisionFragment` 通过 `findLensDetResultAt` 画 overlay。
- **RKNN 污点**：同采样点 `inferFromI420`，结果进 `ProcessVideoAiTimeline.Frame`（boxes/level）并 SSE。
- **lens_det native**：`nativeOpencvStainDetectFromI420` → summary JSON + `target.json`（`x`,`y`）；见 `LENS_DET_NATIVE_API.md`。
- **zero_point**：仅 `ZeroPointDetectCoordinator` + `zpHandle`；**本变更不接入工艺视频**。

## Goals / Non-Goals

**Goals:**

- 500ms Retriever 时间轴 **不变**；每采样 **一帧一检**（lens_det one-shot，已有）。
- 将 lens_det 结果 **并入 timeline 持久化** 与 **HTTP/SSE `running`**，与 RKNN 样本同 `timestampMs`。
- 保持与 RKNN **并行、非阻塞** encode 时钟；`isStainInferBusy` 时 defer（已有）。

**Non-Goals:**

- 工艺视频 **zero_point** JNI / `zero_point_roi.json` / offset 校正。
- 修改 lens_det OpenCV 算法或 native 契约。
- AI Vision 直播 lens_det（已在 `lens-det-app-stream-visualization`；本变更仅收口工艺视频 + SSE）。

## Decisions

### 1. 不实现 zero_point 离线，复用已有 lens_det 调用点

**Decision:** 不添加 `inferZeroPointFromI420` 到 `ProcessVideoAiSession`。仅增强现有 `inferLensDetFromI420` 路径的数据落盘与 SSE。

**Rationale:** 用户明确要求「改成 lens_det」；避免双 OpenCV 模块同帧重复计算。

### 2. Timeline：扩展 `Frame` 或并行 `lensDetByTimeMs`

**Decision:** 在 `ProcessVideoAiTimeline.Frame` 增加可选 `lensDet` 子对象（`success`, `code`, `targetX`, `targetY`），在 RKNN `addFrame` 时若同 `sampleMs` 已有 lens_det 样本则合并；或在 `addFrame` 后 `attachLensDet(sampleMs, result)`。

**Alternative:** 仅内存 `lensDetSamples` — 回放持久化丢失；否决。

### 3. SSE payload

**Decision:** `AiInferenceSseJson` / `running` 增加 `lensDet` 与 stain 字段同级；LAN 客户端可忽略。

### 4. Feature flag

**Decision:** 保持 `BuildConfig.ENABLE_LENS_DET_APP`；文档与 `tasks.md` 要求验收构建开启。可选 v1 默认 `true` for debug — **仅当产品确认**（默认仍 false 直至 PM 签字）。

### 5. Gate

**Decision:** 继续使用 `tryAcceptLensDetProcessVideoInferSample()`（已存在）；session start/stop 时 `resetLensDetProcessVideoFrameSampling()`（确认已调用，缺则补）。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| lens_det 写 `target.json` IO 慢 | 已在 `lens-det-infer` 单飞；不阻塞 playback 线程 |
| Timeline JSON 变大 | lensDet 块可选；旧 cache 无字段时 overlay 仅 RKNN |
| 与 zero_point 文档混淆 | 更新 proposal/tasks；OPENCV 文档区分两模块 |

## Migration Plan

1. Timeline + persistence + SSE。
2. 验证 `resetLensDetProcessVideoFrameSampling` 生命周期。
3. `ENABLE_LENS_DET_APP=true` + `make sync` 设备验收。

Rollback：关闭 `ENABLE_LENS_DET_APP` 或跳过 SSE 新字段（向后兼容）。

## Open Questions

- 是否将 `ENABLE_LENS_DET_APP` 默认改为 `true` 用于 release？
- SSE `lensDet` 是否在 v1 必须进 `device-local-http-ai` 主 spec archive，或仅 change delta。
