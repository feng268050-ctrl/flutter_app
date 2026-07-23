## Why

在快速模式与工程师模式中，实时 AI 推理帧目前通过 `EasyPlayerClientManger` 在**用户开启视频录像**时才拉流并 `pushFrame`，导致激光已开启但未录像时引擎虽收到 `nativeSetLaserOn(true)` 却无帧输入，焊中检测/分类实际不工作。这与产品预期不符：AI 推理应随**激光开关**启停，与是否录像无关；录像走主流 **PR0**，推理走子流 **PR1**，两路互不占用。

## What Changes

- 将生产模式（快速/工程师）下的 **PR1 推理拉流生命周期** 与激光 ON/OFF 绑定，与 `CameraController` 录像按钮解耦。
- 保留 **PR0** 仅用于工艺视频录像（`EasyPlayerClientManger` / `CameraController`），录像开始/结束不再作为推理帧的唯一来源。
- 激光 OFF 时停止 PR1 推理客户端并停止向 `LensGuardManager` 推帧；激光 ON 时在引擎已运行前提下启动 PR1（`CameraConfig.liveInferenceRtspUrl`）。
- 录像与推理可并行：激光 ON + 录像 ON 时 PR0、PR1 各用独立 `EasyPlayerClient`（或等价封装），互不 stop 对方。
- 增加可观测日志：推理流启停原因（`laser_on` / `laser_off` vs `record_start` / `record_stop`）、URL profile（main/sub）。

## Capabilities

### New Capabilities

- `production-ai-inference-stream-lifecycle`: 快速/工程师模式下 PR1 推理流随激光启停、与 PR0 录像流分离的契约与场景。

### Modified Capabilities

- `ai-vision-dual-stream-resolution`: 明确生产模式双码流分工——PR0 仅录制、PR1 仅实时推理，生命周期独立。
- `ai-vision-live-resolution-profile`: 生产模式实时推理必须绑定子流（PR1），且不得依赖录像会话存在。

## Impact

- **代码**：`EasyPlayerClientManger`（拆分或新增推理专用客户端）、`CameraController`、快速/工程师模式激光状态监听（`DeviceStatus` / `LensGuardManager` 已有激光推送）、可能的 `LaserApplication` 或模式 Activity 协调类。
- **行为**：激光 ON 未录像时即可焊中 AI；仅录像不开光时不再误推 PR0 帧给推理（若此前依赖录像推帧）。
- **验证**：激光 ON/OFF × 录像 ON/OFF 四象限；日志确认 PR1 与 PR0 URL；与 AI Vision Tab 子流策略不冲突。
