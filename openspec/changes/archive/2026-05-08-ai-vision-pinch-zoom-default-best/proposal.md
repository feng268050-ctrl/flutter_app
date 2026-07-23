## Why

AI Vision 右侧视频流当前不支持手势缩放，现场查看细节时需要依赖固定视角，影响可用性与检测确认效率。现在需要补齐双指放大/缩小与可感知的缩放档位状态（default/best），以提升操作直觉与诊断体验。

## What Changes

- 在 AI Vision 右侧实时视频区域新增双指捏合放大/缩小能力。
- 首次进入 AI Vision 时，视频显示状态固定为 `default`（1x 基准视图）。
- 当缩放倍率达到阈值时，界面状态切换为 `best`（阈值由测试后回填）。
- 缩放倍率设定上限（具体最大倍率由测试后回填），并在超限时钳制。
- 维持现有 RTSP 拉流与 AI 叠层链路，不改变推理协议与数据来源。

## Capabilities

### New Capabilities
- `ai-vision-gesture-zoom`: 规范 AI Vision 视频流的双指缩放交互、default/best 状态切换规则与倍率边界行为。

### Modified Capabilities
- None.

## Impact

- Affected UI: `AiVisionFragment` 右侧视频区域手势交互与缩放状态展示。
- Affected code: 视频视图手势处理（ScaleGestureDetector / Matrix）、缩放状态映射逻辑、相关字符串资源与测试用例。
- APIs/dependencies: 无新增后端 API；优先复用 Android 原生手势能力，无额外三方依赖。
