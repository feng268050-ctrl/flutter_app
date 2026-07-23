## Why

快速模式「更多监测」弹窗（`WorkStatusDialog` + `MachineStatusDialogFragment`）仍使用白色 `XUILinearLayout` 容器和 `@mipmap` / `@drawable` 按钮背景，与已迁移到 `FrostedGlassCard` / `FrostedGlassButton` 的 Monitor → Machine Status 页面视觉不一致。Monitor 机台状态为适配黑色底图采用了透明卡片（`cardBackground="transparent"`），而快速模式弹窗位于浅色对话框内，需要**实时背景模糊**（而非固定深色渐变块）以呈现黄白毛玻璃质感。统一该入口的卡片与按钮样式可减少 legacy 资产依赖，并与 HMI 设计系统对齐。

实现过程中发现：`FrostedGlassCard` 原先仅有 `FrostedGlassPanelDrawable` 固定填充、无 `BlurView`，在浅色弹窗底上会发灰；Monitor 与弹窗两处机台状态布局高度重复；`FrostedGlassDialog` 与卡片自带 blur 存在双层叠加。上述问题已在本变更中一并解决。

## What Changes

### 原范围（更多监测弹窗）

- 将 `fragment_machine_status_dialog.xml` 中的两个环形仪表容器与六个状态瓦片由 `XUILinearLayout` + 白色背景替换为共享组件 `MachineStatusGaugeCard` / `MachineStatusStatusTile`（dialog 变体：`cardBackground="frosted"`，启用 backdrop blur）。
- 环形仪表沿用 Monitor Machine Status 的 `borderGradientCenter` 左右不对称方案；状态瓦片使用 `top-left-bottom-right`。
- 将 `work_status_dialog.xml` 底部「我知道了」确认按钮替换为 `FrostedGlassButton`（`primary`）。
- 将 `laser_progress.xml` 中「更多监测」入口按钮替换为 `FrostedGlassButton`（`default`，保留右箭头）。
- 移除 `MachineStatusDialogFragment` 中对 `XUILinearLayout.setRadiusAndShadow` 的运行时圆角/阴影设置；保留快速模式 `ARG_QUICK_MODE_MORE_MONITOR` 下的 gauge 裁剪放宽逻辑。
- 保留数据绑定、Modbus 状态展示、弹窗尺寸与 `showButton` 行为。

### 扩展范围（实现期纳入）

- **共享机台状态组件**：新增 `MachineStatusGaugeCard`、`MachineStatusStatusTile`、`MachineStatusChrome`（`monitor` / `dialog` 预设）、`MachineStatusBindingAdapter`；`fragment_machine_status.xml` 与 `fragment_machine_status_dialog.xml` 均改用上述组件，消除重复布局与 chrome 逻辑。
- **状态瓦片对称内边距**：标签至左缘与复选框至右缘均使用 `frosted_glass_content_padding`（24dp）。
- **`FrostedGlassCard` backdrop blur**：新增 `FrostedGlassBlurSupport`；`frosted` 模式下卡片内建 `BlurView`，通过本地或 Activity `BlurTarget` 采样背后内容；blur 生效时默认不叠加深色 `PanelDrawable`（避免浅色底发灰）。
- **`work_status_dialog.xml` BlurTarget**：黄白壁纸层包裹 `BlurTarget`，供弹窗内卡片在同一窗口内采样模糊。
- **`FrostedGlassDialog` 单层雾化**：`dialog_frosted_glass_prompt.xml` 移除外层 `BlurView`，由单个 `FrostedGlassCard` 负责 blur；`frostedGlassStackPanelFill="true"` 仅用于此类 **FrostedGlassDialog 提示壳**（恢复重构前 blur + panel 叠色浓度），**不**用于 more monitor 机台状态卡片。
- **`FrostedGlassOverlayHost` 精简**：不再对内容区调用外层 blur setup；输入类 dialog IME 锚点改为 `frosted_glass_content`。
- **Dialog 变体 typography**：浅色模糊底上使用黑色标签 + `highlight_check_box`、黑色仪表刻度（与 Monitor 白字场景区分）。

**不改动：** `WorkStatusDialog` 外层 `@mipmap` 对话框壳整体结构（仅增加 `BlurTarget` 包裹壁纸层）；告警、工艺参数等业务逻辑不变。

## Capabilities

### New Capabilities

- `quick-mode-more-monitor-glass-cards`: 快速模式「更多监测」及共享 `MachineStatusDialogFragment` 内容区的雾化卡片与按钮规范；要求 **backdrop blur + frosted 语义**，与 Monitor 透明卡片及 `FrostedGlassDialog` 提示壳的 stack panel fill 场景区分。

### Modified Capabilities

- `frosted-glass-components`（实现层，无独立 delta spec）：`FrostedGlassCard` 增加 backdrop blur、`frostedGlassStackPanelFill` 属性；`FrostedGlassDialog` prompt 布局改为单层卡片结构。

## Impact

- 布局：`fragment_machine_status_dialog.xml`、`fragment_machine_status.xml`、`work_status_dialog.xml`、`laser_progress.xml`、`dialog_frosted_glass_prompt.xml`
- Java（弹窗）：`MachineStatusDialogFragment.java`
- Java（新组件）：`component/machine/*`、`MachineStatusBindingAdapter.java`
- Java（玻璃基础设施）：`FrostedGlassCard.java`、`FrostedGlassBlurSupport.java`、`FrostedGlassOverlayHost.java`、`FrostedGlassTextInputDialog.java`、`FrostedGlassNumericInputDialog.java`
- 资源：`attrs.xml`、`dimens.xml`、`styles.xml`、`ids.xml`；删除 `pressure_monitoring_btn_{green,blue,orange}.xml`
- 工程师模式枪头自动弹出的同一机台状态面板视觉同步更新（共享布局）
