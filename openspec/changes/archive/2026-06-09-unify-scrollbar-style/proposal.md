## Why

需要上下滚动的页面当前滚动条样式不统一：工程师模式参数面板使用 `EngineerParameterScrollView` + `engineer_scroll_view_style`，滚动时才显示、`insideOverlay`、无轨道；安全提示、升级说明、设备信息、WiFi/蓝牙等页面则在布局中手写 `scrollbar_thumb_disclaimer` / `scrollbar_track_disclaimer`、固定显示和不同轨道样式。现在需要以工程师模式参数面板为视觉基准，统一全局纵向滚动条，减少页面间视觉割裂和重复配置。

## What Changes

- 新增统一的全局纵向滚动条样式，以工程师模式参数面板当前交互为准：竖向滚动条、`insideOverlay`、默认渐隐、仅在用户滚动后唤醒显示、滑块使用统一白色圆角视觉，默认不显示独立轨道。
- 提供可复用的 ScrollView 容器或基础样式，使需要上下滚动的普通页面不再逐个手写 thumb/track/size/fade/style 属性。
- 将已有上下滚动页面迁移到统一样式，包括工程师模式参数页、参数详情、高级设置、安全/使用安全提示、升级说明、设备信息、WiFi/蓝牙列表等显式纵向滚动场景。
- 移除或停止使用与全局样式冲突的页面级滚动条资源配置，例如 `scrollbar_thumb_disclaimer` / `scrollbar_track_disclaimer` 直连配置。
- 保留页面原有滚动内容、布局尺寸、列表数据、点击行为和业务逻辑；本次只统一纵向滚动条视觉与显示行为。

## Capabilities

### New Capabilities

- `global-scrollbar-style`: 定义应用内需要上下滚动页面的统一纵向滚动条视觉、显示行为和复用接入要求。

### Modified Capabilities

- `engineer-mode-common-params`: 工程师模式参数面板继续作为统一滚动条样式基准，并保持滚动前不显示、用户滚动后显示的行为。
- `parameter-settings`: 参数/高级设置类可滚动页面 SHALL 使用全局滚动条样式，不再使用页面私有滚动条外观。

## Impact

- **Java/UI components**: 可能复用或泛化 `EngineerParameterScrollView` 的“用户滚动后才显示滚动条”行为，作为普通页面可使用的全局滚动容器。
- **Styles/resources**: 更新 `base_scroll_view_style`、`engineer_scroll_view_style` 或新增全局 style；统一 `scroll_thumb` / track 使用策略；清理不再使用的 disclaimer 滚动条资源引用。
- **Layouts**: 更新所有显式纵向滚动页面的 XML 配置，使 `ScrollView`、可滚动列表外层容器等使用统一样式，同时保留原本的宽高、margin、padding 和内容结构。
- **No API/dependency changes**: 不新增外部依赖，不改变数据接口、数据库、Modbus/WebSocket 或业务流程。
