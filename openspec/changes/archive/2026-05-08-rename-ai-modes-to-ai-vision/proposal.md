## Why

当前 Device detection 页面中的 `AI Modes` 文案与设备端“视觉识别”命名不一致，且顶部/侧边存在冗余控制区（截图框选部分），导致认知成本和操作路径偏长。现在需要统一命名与视觉语言，确保页面与设备端风格一致，减少用户在跨端使用时的理解偏差。

## What Changes

- 将 Device detection 页面中的 `AI Modes` 统一改为 `AI Vision`（包含顶部导航与相关入口文案）。
- 移除截图中框选的冗余 UI 区域（顶部双开关区域与右侧三按钮区域），保留左侧“工作模式信息区”。
- 将右侧主画面区域改为实时视频流显示，用于持续呈现设备当前采集画面。
- 补充实时流落地条件：使用 `rtsp://` 作为流地址，播放器需包含 RTSP source 能力，并提供加载中/失败/重连提示。
- 对 AI 相关区域进行视觉样式收敛，统一与设备端的配色、圆角、间距和信息层级表现。
- 保持现有核心检测流程不变，确保变更主要限于文案与界面结构/样式。

## Capabilities

### New Capabilities
- `device-detection-ai-vision-alignment`: 规范 Device detection 页面 AI 区域命名、结构裁剪与视觉风格，确保与设备端设计一致。

### Modified Capabilities
- None.

## Impact

- Affected UI: Device detection 页面导航与 AI 内容区布局、样式与文案资源（含左侧信息区保留、右侧视频流区域）。
- Affected code: Android 布局 XML、Fragment/Activity 中 tab 配置、视频流视图绑定逻辑、`strings.xml`（含多语言资源）。
- Runtime prerequisites: 设备网络可达摄像头 RTSP 地址，应用构建包含 RTSP 播放依赖，流异常时可观测。
- APIs/dependencies: 无新增外部依赖，无接口协议变更。
