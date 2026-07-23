## Why

快速模式与工程师模式中，子码流解码回调对每一帧 I420 都调用 `LensGuardManager.onI420Frame`，导致 RKNN 推理与拷贝在焊接场景下持续占满 CPU，与 Modbus、录制、UI 等作业争抢资源。AI Vision 直播预览已通过 Handler 每 500ms 从 TextureView 抽帧，性能表现正常。需要抽象统一的抽帧推理能力，让生产模式与 AI Vision 复用同一套节流逻辑，并按场景配置不同抽帧间隔。

## What Changes

- 新增可复用的抽帧推理门控（frame-sampling gate）：在帧进入 `LensGuardManager` 的 `guardedPushFrame` 路径之前，按可配置的 `sampleIntervalMs` 丢弃间隔内的帧。
- 快速模式 / 工程师模式（生产子码流）：抽帧间隔 **2000ms**（每 2 秒最多推理一帧）；解码回调仍可收到全帧，但仅按间隔向引擎推送。
- AI Vision 直播预览：保持 **500ms** 抽帧间隔；将 `AiVisionFragment` 内联的 Handler 抽帧逻辑迁移到共享抽象，行为不变。
- 明确 AI Vision 离线视频抽帧（约 500ms，`inferJpgToJson`）不在本次统一范围内——该路径已是文件级抽帧，不经过 I420 推送。
- 增加可观测日志：记录 profile（`production` / `ai-vision-live`）、配置间隔、实际推送与丢弃计数（调试级别）。

## Capabilities

### New Capabilities

- `ai-frame-sampling-inference`: 统一的抽帧推理门控契约、各场景默认间隔、与 `LensGuardManager` 的集成方式及性能退化语义。

### Modified Capabilities

- `production-ai-inference-stream-lifecycle`: 子码流帧推送 SHALL 经抽帧门控，默认间隔 2000ms，而非每解码帧推送。
- `ai-vision-live-resolution-profile`: 生产模式 `onI420Frame` 接收语义更新为「解码全帧 + 抽帧推送」；明确与 AI Vision 直播路径的间隔差异。
- `ai-vision-live-video`: 强化「推理不得主导视频管线」——生产模式通过固定 2s 抽帧满足；AI Vision 直播保持 500ms 抽帧。

## Impact

- **代码**: `LensGuardManager`（或新建 `com.lasercyber.lws.ai` 下的门控类）、`ProductionInferenceStreamClient`、`AiVisionFragment`、`ProductionInferenceStreamCoordinator`（如需 profile 切换）。
- **性能**: 生产模式推理 CPU 负载预计降至约原来的 1/(fps×2s) 量级（相对 25fps 约 50× 减少推送次数）。
- **行为**: 生产模式污染检测时间分辨率降为 2s；告警/快照仍依赖 `publishLastClsSnapshotIfDue` 等既有周期逻辑，需验证 2s 间隔是否满足产品预期。
- **测试**: 扩展 `ProductionInferenceStreamCoordinatorTest` 或新增门控单元测试；手动矩阵：激光开 × 快速/工程师 × AI Vision 直播。
- **规格**: 不修改离线 `inferJpgToJson`、双码流 URL 或激光生命周期触发条件。
