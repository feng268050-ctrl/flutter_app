## Why

AI Vision 在高运动场景下仍会出现明显停顿，核心压力来自单路高分辨率码流同时承担实时显示/推理与录制。将实时推理链路改为 **独立子码流**（现场参考 **640×512** + H.264 Baseline + 768K CBR 等，见 `docs/dual-stream-workflow.md`），并保留 **1920×1080** 主流录制，可以在不牺牲录像质量的前提下降低解码与 AI 路径压力。**1280×720** 仍为可选子码流分辨率。

## What Changes

- 增加 AI Vision 视频流分层策略：录制链路优先高质量（1080p），实时推理/显示链路走 **子码流**（分辨率由 IPC 配置，如 640×512）。
- 支持摄像头具备子码流能力时的双码流选择：主码流用于录制，子码流用于实时显示与推理。
- 当摄像头不支持子码流时，定义降级策略：单码流或回退主流，并保留录制可用性。
- 明确 640x640 的定位：作为模型前处理输入尺寸候选，而非默认摄像头输出分辨率，避免画面比例失真。
- 增加可观测性：记录实际连接的流 URL、实时分辨率、解码路径（硬/软解）以及关键回退原因。

## Capabilities

### New Capabilities
- `ai-vision-dual-stream-resolution`: AI Vision 的双码流分工（1080p 录制 + 子码流实时推理）与单码流降级规则。
- `ai-vision-live-resolution-profile`: AI Vision 实时链路走子码流；模型 640 输入仅用于前处理。

### Modified Capabilities
- （无）当前 `openspec/specs/` 下无可直接复用的 AI Vision 实时视频分辨率能力，采用新增能力定义。

## Impact

- **代码**：`CameraConfig`、`AiVisionFragment`、`EasyPlayerClientManger`、`BackgroundLoopRecorder`、可能的 `CameraRemote`（读取/设置摄像头码流配置）与调试入口。
- **系统/设备**：依赖 IPC 是否支持主/子码流与独立分辨率配置；需现场确认 RTSP 路径（例如 `/PR0` `/PR1`）。
- **验证**：需要增加双码流可用性检查、实时推理流 FPS/延迟对比、录制清晰度回归验证。
