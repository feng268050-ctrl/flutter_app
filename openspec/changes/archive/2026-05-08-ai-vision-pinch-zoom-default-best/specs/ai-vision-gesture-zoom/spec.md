## ADDED Requirements

### Requirement: AI Vision video panel MUST support pinch zoom
AI Vision 右侧实时视频区域 MUST 支持双指放大与缩小，并在手势过程中连续更新缩放倍率。

#### Scenario: User pinches to zoom in and out
- **WHEN** 用户在 AI Vision 视频区域执行双指捏合手势
- **THEN** 视频画面 SHALL 按手势方向连续放大或缩小，而不影响实时流播放连续性

### Requirement: Initial zoom state SHALL be default on first open
AI Vision 页面首次打开时，视频缩放倍率 MUST 为 1x，且缩放状态 MUST 显示为 `default`。

#### Scenario: First entry initializes default state
- **WHEN** 用户首次进入 AI Vision 页面
- **THEN** 视频显示倍率 MUST 为 1x 且状态标识 MUST 为 `default`

### Requirement: Zoom state MUST switch to best at configured threshold
当视频缩放倍率达到或超过 `best` 阈值时，系统 MUST 将状态切换为 `best`；该阈值 SHALL 由可配置常量承载并允许后续按测试结果回填。

#### Scenario: Threshold crossing updates state to best
- **WHEN** 用户将视频缩放至不小于 `bestThreshold`
- **THEN** 页面缩放状态 MUST 从 `default` 更新为 `best`

### Requirement: Zoom ratio MUST be clamped by maximum limit
视频缩放倍率 MUST 受最大倍率限制，超过上限时系统 MUST 执行倍率钳制；最大倍率 SHALL 由可配置常量承载并允许后续按测试结果回填。

#### Scenario: Overscaled gesture is clamped
- **WHEN** 用户持续放大并尝试超过 `maxZoom`
- **THEN** 实际显示倍率 MUST 不超过 `maxZoom`

### Requirement: Zoom interaction MUST coexist with AI overlays
缩放交互启用后，AI 状态叠层与检测框叠层 MUST 与视频显示保持可用，不得因缩放导致功能失效或崩溃。

#### Scenario: Overlays remain functional while zooming
- **WHEN** 用户在 AI Vision 页面进行缩放交互且推理结果持续更新
- **THEN** AI 状态信息与检测框叠层 MUST 继续显示并保持交互稳定
