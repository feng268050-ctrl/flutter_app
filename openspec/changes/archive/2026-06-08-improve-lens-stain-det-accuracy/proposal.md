## Why

AI Vision 工艺视频 Detect 当前对每一帧的 OpenCV stain detect 结果采用「有框即脏污」策略，单帧误检会直接触发 overlay 高亮，并在 replay 时 hold-forward 显示，误伤率高。需要在整段检测结束后，对全部采样帧的 boxes 做时序归约，只保留在多帧中稳定出现的脏污区域，再据此给出最终判定与展示。

## What Changes

- 新增 **时序 box 归约算法**：检测会话结束后，收集 timeline 中所有帧的 pixel-space boxes，以 **±10 px** 容差合并相同/相邻框，统计各簇出现次数，**保留出现次数 ≥ 3** 的簇作为最终脏污区域（两项阈值均为类常量，便于后续调参）。
- **追加最终汇总帧**：在 `ProcessVideoAiSession` 结束流程中，将归约后的 boxes 写入 timeline 最后一帧（timestamp 取视频时长或末采样时刻），并通过 SSE 推送一条 **`running`** 事件（在 **`stop`** 之前），供 UI 与 LAN 客户端最终展示。
- **脏污判定与告警**：以归约后的最终帧（而非任意单帧）判定是否存在脏污；若存在持久 box 则进入现有镜片脏污告警流程（`LensCheckResultEvent`），否则视为 clean。
- **Per-frame 行为不变**：检测进行中仍逐帧推送 SSE；overlay **仅展示当前采样时刻**的 boxes（无 hold-forward），避免误检框残留。
- **移除 AI Vision hold-forward 显示**：工艺视频 Detect/Replay 与 Live RTSP 预览均不再保留「最近一次有框」；当前样本无框则 overlay 清空（Detect 完成后仍以汇总帧为准）。
- **持久化**：timeline JSON 持久化 **MUST** 包含汇总帧，replay 接口与 AI Vision replay 读取同一结果。

## Capabilities

### New Capabilities

- `lens-stain-temporal-box-reduction`: 工艺视频检测结束后的 box 聚类归约、最终汇总帧、SSE 顺序与脏污判定契约。

### Modified Capabilities

- `ai-vision-recorded-video-realtime`: 去掉 hold-forward；Detect 进行中按 `findFrameAt` 逐帧展示；完成后以汇总帧为准。
- `ai-vision-live-inference-overlay`: Live RTSP 去掉 hold-forward；仅展示最新完成样本的 boxes，无框则清空。
- `ai-frame-sampling-inference`: AI Vision 相关 overlay 场景删除 hold-forward 要求（产线 live weld 不变）。
- `device-local-http-video-ai`: SSE 生命周期 **MUST** 在 `stop` 前追加一条汇总 `running` 事件；`stop` 的 `reason` 语义不变。
- `lens-det-app-inference`: 工艺视频路径的最终 dirty/clean 输出 **MUST** 来自归约结果；AI Vision overlay **不再** hold-forward（见 `ai-vision-live-inference-overlay`）。
- `ai-vision-lens-dirty-alerts`: AI Vision 工艺视频 Detect 完成后 **MAY** 依据汇总帧发布 `LensCheckResultEvent`（offline source 仍 **MUST NOT** 触发生产焊接 deferred L001 告警）。

## Impact

- **Java**: …；`AiVisionFragment` 移除 `findLastFrameWithDetectionAt` / `findLastStainDetectWithTargetAt` / `OpencvStainDetectHoldForwardStore` 的 overlay 路径；Live 路径移除 `AiHoldForwardStore` 残留展示逻辑。
- **测试**: reducer 单元测试（容差合并、计数阈值、空输入）；session 集成测试（SSE 顺序：最后 `running` 在 `stop` 前）；timeline 持久化含汇总帧。
- **无 native 变更**；无 breaking HTTP route 变更。
