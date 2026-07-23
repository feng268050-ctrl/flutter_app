## ADDED Requirements

### Requirement: AI entry naming SHALL be unified to AI Vision
Device detection 页面中面向用户可见的 AI 入口与相关标题文案 MUST 统一使用 `AI Vision`，不得再显示 `AI Modes`。

#### Scenario: Top navigation label is unified
- **WHEN** 用户进入 Device detection 页面并查看顶部导航
- **THEN** 原 `AI Modes` 入口 MUST 显示为 `AI Vision`

#### Scenario: No stale AI Modes text remains
- **WHEN** 用户在该页面切换语言并浏览 AI 区域相关文案
- **THEN** 可见文案 MUST 不再出现 `AI Modes`

### Requirement: Highlighted redundant control regions SHALL be removed
截图中框选的顶部双开关区域与右侧三按钮区域 MUST 从页面结构中移除，而不是仅视觉隐藏；页面 SHALL 保留左侧工作模式信息区用于展示工作参数。

#### Scenario: Top toggle strip is absent
- **WHEN** 用户打开 Device detection 页面
- **THEN** 页面顶部不再显示 `AI Camera` / `AI Vision Training` 双开关条

#### Scenario: Right-side action stack is absent
- **WHEN** 用户查看检测主视图右侧
- **THEN** 页面不再显示 `Skip`、`Okay`、`Reselect` 三个纵向按钮

### Requirement: Right panel SHALL display live video stream
Device detection 页面右侧主画面区域 MUST 显示设备实时视频流，并在流未就绪时提供明确的加载或失败提示，不得长期停留在静态占位图。

#### Scenario: Live stream is visible during normal operation
- **WHEN** 设备视频流连接正常且页面处于前台
- **THEN** 用户在右侧主画面区域 SHALL 看到持续更新的实时视频画面

#### Scenario: Stream state is communicated when unavailable
- **WHEN** 视频流初始化失败或中断
- **THEN** 右侧区域 MUST 显示清晰的失败状态提示，并支持后续恢复显示实时画面

#### Scenario: RTSP playback capability is present
- **WHEN** AI Vision 页面使用 `rtsp://` 地址拉取实时流
- **THEN** 应用 MUST 具备 RTSP media source 支持，且点击 `AI Vision` 不得因媒体源能力缺失导致崩溃

### Requirement: Page visual style SHALL align with device-side design language
Device detection 页面中 AI 相关区域 MUST 与设备端保持一致的视觉风格，包括颜色语义、圆角层次、间距节奏与信息主次关系。

#### Scenario: Visual language matches device baseline
- **WHEN** 设计/测试人员对照设备端基线截图检查页面
- **THEN** AI 区域的配色、圆角、间距和信息层级表现 SHALL 与设备端风格一致，不出现明显风格割裂
