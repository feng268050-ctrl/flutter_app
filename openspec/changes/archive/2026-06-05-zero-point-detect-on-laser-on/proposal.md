## Why

零点检测 native API（`NativeBridge` zero-point JNI）已在 `libai.so` 中可用，但 App 尚未定义「何时抽帧、如何汇总结果、如何写回零点校正」。产品需要在**激光开启**后自动做短时零点检测，并根据检测偏移更新 Modbus **0090H** 零点校正，减少人工在高级设置里反复微调。

## What Changes

- 新增 **零点检测任务**：在激光 **由关→开** 的上升沿触发；**首个采样在激光开启后 500ms**；之后 **每 500ms** 抽一帧送入 native zero-point detect，**持续 2s**（共 **4 次**采样：+500ms、+1000ms、+1500ms、+2000ms）。
- 抽帧与限频复用现有 **`AiFrameSamplingInterval`（500ms）** 与 **`AiFrameSamplingGate`** 契约（与 AI Vision 直播/工艺视频 500ms 路径一致），在专用 worker 上调 `nativeOpencvZeroPointDetectFromI420`（或等价的 I420 路径）。
- 解析 native 返回 JSON 的 **`offset_x`**（像素）；按 **UI 1 单位 = 3px**、**符号取反**（JSON 为负 → UI 增加，JSON 为正 → UI 减少）计算校正增量，**累加**到当前 `zeroPointCorrection` 并 **clamp 到 [-30, 30]**。
- 任务结束后通过现有 Advanced Settings / Modbus 写流程下发 **0090H**（`zeroPointCorrection × 10`），并更新 Room / UI 显示。
- 激光关闭、重复开激光、或任务进行中新一次上升沿：取消/替换进行中的任务（见 design）。
- 检测失败或有效样本不足：不修改零点校正，记录日志（可选 Toast 由 design 定）。

## Capabilities

### New Capabilities

- `zero-point-detect-on-laser-on`: 激光开启触发的 500ms×4 抽帧零点检测任务、JSON `offset_x` 到 UI/Modbus 零点校正的换算与写入。

### Modified Capabilities

- `ai-frame-sampling-inference`: 增加 zero-point 任务对 500ms gate 的使用场景（与 `AI_VISION_LIVE` 同间隔，独立 gate 实例，避免与 AI Vision 预览互相抢 timestamp）。

## Impact

- **Java**: 新 coordinator（建议 `ZeroPointDetectCoordinator` 或并入现有 laser/camera 协调层）、`AiManager` / `NativeBridge` 调用、激光状态监听（`MemoryCacheManager` / `DeviceStatus`）。
- **Native**: 无 API 变更；依赖已有 `nativeCreateOpencvZeroPointDetector` / `nativeOpencvZeroPointDetectFromI420` 与 ROI JSON 路径。
- **Settings**: `AdvancedSettingFragment`、`ModbusFiledBuilder`（0090H）、`AdvancedSettingDataCheck`（±30）。
- **Camera**: 帧来源需与现有 I420 子码流或录制/预览路径对齐（design 选型）。
- **Specs**: 新 capability spec；`ai-frame-sampling-inference` delta。
