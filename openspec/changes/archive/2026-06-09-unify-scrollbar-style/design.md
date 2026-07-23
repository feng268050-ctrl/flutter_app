## Context

工程师模式参数面板已经有较接近目标的滚动条体验：`EngineerParameterScrollView` 在用户真正滚动前不唤醒滚动条，`engineer_scroll_view_style` 继承 `base_scroll_view_style`，使用 `insideOverlay`、渐隐滚动条和无轨道配置。与此同时，多个普通页面在 XML 中重复手写 `android:scrollbarThumbVertical="@drawable/scrollbar_thumb_disclaimer"`、`android:scrollbarTrackVertical="@drawable/scrollbar_track_disclaimer"`、`android:scrollbarSize="10dp"`、`android:fadeScrollbars="false"`、`outsideInset` 等属性，导致安全提示、升级说明、设备信息、WiFi/蓝牙列表等页面与工程师参数面板视觉不一致。

当前项目已有基础资源 `scroll_thumb` / `scroll_track` 与 `base_scroll_view_style`，也已有工程师专用滚动容器行为。这个变更不需要引入新依赖或改动业务流程，重点是把工程师参数面板的滚动条视觉和显示行为变成可复用的全局约定，并迁移现有显式上下滚动页面。

## Goals / Non-Goals

**Goals:**

- 以工程师模式参数面板为基准统一应用内纵向滚动条：白色圆角滑块、`insideOverlay`、默认渐隐、默认无独立轨道。
- 提供普通页面可复用的滚动容器或 style，避免页面重复手写滚动条 drawable/尺寸/显示行为。
- 迁移现有显式纵向滚动页面，保留原有内容结构、布局尺寸、padding/margin、列表数据和业务交互。
- 让工程师参数面板继续保持“未发生用户滚动前不显示滚动条”的体验。

**Non-Goals:**

- 不改变任何页面的信息架构、数据来源、保存逻辑或点击行为。
- 不统一横向滚动、ViewPager2、WheelView、图表拖拽或非滚动条视觉控件。
- 不重做列表分页、刷新加载、空状态、告警弹窗或 FrostedGlass 弹窗壳层。
- 不新增外部 UI 库或改变 Android 主题体系。

## Decisions

### 1. 将工程师滚动行为泛化为全局容器

新增一个语义更通用的滚动容器，例如 `GlobalStyledScrollView` 或 `AppScrollView`，承载 `EngineerParameterScrollView` 当前的 `awakenScrollBars` 行为：只有用户发生垂直滚动后才允许系统唤醒滚动条。`EngineerParameterScrollView` 可改为继承这个全局容器，或直接替换工程师布局中的类名。

**理由：** 仅靠 XML style 无法表达“滚动前不唤醒滚动条”的行为。复用 Java 容器可以保持工程师参数面板现有体验，并让普通页面接入同一交互。

**替代方案：** 只更新 XML style，不新增容器。该方案能统一颜色和尺寸，但无法统一唤醒行为，容易继续出现页面间差异。

### 2. 建立一个全局纵向滚动条 style

新增或重命名为明确的全局 style，例如 `app_vertical_scroll_view_style`，作为需要上下滚动页面的默认接入点。该 style 继承现有 `base_scroll_view_style` 的基础配置，但与工程师基准保持一致：`android:scrollbars="vertical"`、`android:scrollbarStyle="insideOverlay"`、`android:fadeScrollbars="true"`、统一 `android:scrollbarSize`、统一 thumb drawable、默认 track 为 `@null`。

`engineer_scroll_view_style` 保留工程师页面的布局宽高和 margin 属性，但滚动条视觉属性从全局 style 继承，避免两套定义漂移。

**理由：** 全局 style 让 XML 迁移成本低，也方便后续新页面直接复用。

**替代方案：** 直接修改 `base_scroll_view_style` 并要求所有页面使用它。风险是 `base_scroll_view_style` 可能已承担更宽泛布局语义，显式全局滚动条 style 的意图更清晰。

### 3. 逐页迁移显式纵向滚动场景

迁移对象包括但不限于：

- 工程师模式参数页：`fragment_engineer_cutting.xml`、`fragment_engineer_wash.xml`、`fragment_engineer_welding.xml`
- 参数/设置详情页：`fragment_advanced_setting.xml`、`fragment_process_video_details.xml`、`activity_process_video_details.xml`
- 说明和信息页：`activity_safety_tips.xml`、`activity_use_safety_tips.xml`、`activity_upgrade.xml`、`fragment_device_information.xml`
- 设备列表外层滚动页：`activity_wifi.xml`、`activity_bluetooth.xml`
- 其他显式 `android:scrollbars="vertical"` 且属于页面上下滚动的布局

迁移时保留每个页面已有的高度、margin、padding、`fillViewport`、`clipToPadding` 等布局语义，只替换滚动条视觉和显示行为。对于 `RecyclerView` 本身可滚动且没有外层 `ScrollView` 的页面，本次只在已有滚动条可见需求明确时接入，不强行包裹或改变列表结构。

**理由：** 本需求是视觉统一，不应引入嵌套滚动或改变测量行为。

**替代方案：** 一次性对所有 `RecyclerView` 设置滚动条样式。该方案覆盖面大但风险更高，可能影响列表性能和触控体验。

### 4. 清理冲突的页面私有资源引用

页面不再直接引用 `scrollbar_thumb_disclaimer` / `scrollbar_track_disclaimer`。如果迁移后没有其他合法引用，删除这些资源；否则保留但不作为普通页面默认滚动条来源。

**理由：** 重复 drawable 会让后续样式调整再次分叉。

**替代方案：** 保留 disclaimer 资源并改成与全局一致。该方案减少删除风险，但仍保留两个命名上绑定特定场景的资源，长期可维护性较差。

## Risks / Trade-offs

- **[Risk] 某些页面依赖固定显示滚动条提示可滚动** -> 迁移后真机检查关键说明页，确认内容仍能通过布局和触控自然发现；如确有业务要求，可在 spec 中显式列为例外。
- **[Risk] `insideOverlay` 覆盖内容边缘** -> 保留或微调页面右侧 padding/margin，不改变内容层级；重点检查窄列表和说明文本页面。
- **[Risk] 替换外层 `ScrollView` 类名影响布局预览或反射绑定** -> 仅替换标准 XML ScrollView 或已有工程师自定义 ScrollView，保持构造函数完整；不触碰 RecyclerView adapter 逻辑。
- **[Risk] 删除 disclaimer 资源时遗漏引用** -> 使用资源引用搜索确认无引用后再删除，并运行构建或至少 lint/resource 检查。

## Migration Plan

1. 新增全局 ScrollView 容器，复用 `EngineerParameterScrollView` 的滚动条唤醒逻辑。
2. 新增全局纵向滚动条 style，并让 `engineer_scroll_view_style` 继承或复用该 style。
3. 将工程师参数面板切到全局容器或让现有工程师容器继承全局容器，确认视觉不回退。
4. 迁移普通页面中显式上下滚动的 `ScrollView` 配置，移除手写 thumb/track/fade/style 属性。
5. 检查并清理不再使用的滚动条 drawable 资源引用。
6. 真机或模拟器回归工程师模式参数面板、说明页、设备信息页、WiFi/蓝牙页、高级设置页的滚动条显示时机和内容边距。

Rollback 很简单：回退 XML style/容器引用即可，不涉及数据迁移或协议兼容。

## Open Questions

- WiFi/蓝牙页面当前存在 `ScrollView` 包裹 `RecyclerView` 的结构，本次是否只统一外层滚动条，还是顺手改为 RecyclerView 自身滚动，需要 implementation 时根据现有页面表现确认。
- `ListView`/picker 类 body（例如时区选择）是否也要纳入统一滚动条样式；默认建议只纳入普通页面上下滚动，不改 picker 控件内部滚动体验。
