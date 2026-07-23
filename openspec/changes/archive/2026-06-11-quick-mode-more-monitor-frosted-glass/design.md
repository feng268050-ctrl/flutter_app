## Context

快速模式仪表盘（`laser_progress.xml`）提供「更多监测」入口，点击后通过 `GeneralOperationsFragment` 打开 `WorkStatusDialog(showButton=true)`，内嵌 `MachineStatusDialogFragment`（`ARG_QUICK_MODE_MORE_MONITOR=true`）。工程师模式枪头打开时亦通过 `WorkStatusDialogBuilder` 弹出同一内容（`showButton=false`）。

Monitor → Machine Status（`fragment_machine_status.xml`）与弹窗（`fragment_machine_status_dialog.xml`）原先各自维护重复的 gauge/tile 布局与 chrome。本变更在迁移弹窗的同时抽取共享组件，并补齐 `FrostedGlassCard` 的实时模糊能力。

`WorkStatusDialog` 整体壳层在 prompt 迁移中明确排除，不在本次迁移至 `FrostedGlassDialog`；仅在壁纸层增加 `BlurTarget` 以支持卡片模糊。

## Goals / Non-Goals

**Goals:**

- 弹窗内 gauge/tile 使用 `MachineStatusGaugeCard` / `MachineStatusStatusTile`（`machineStatusVariant="dialog"`），`cardBackground="frosted"` 表示启用 backdrop blur。
- 弹窗卡片在浅色黄白壁纸上呈现**毛玻璃**（blur + tint），而非固定深色 `PanelDrawable` 灰块。
- Monitor 页复用同一套组件，`machineStatusVariant="monitor"`，`cardBackground="transparent"`。
- `FrostedGlassDialog` 提示弹窗恢复重构前的雾化浓度（`frostedGlassStackPanelFill="true"`），且仅单层 `FrostedGlassCard`（无外层 BlurView 双重模糊）。
- 按钮、尺寸、数据绑定、Modbus 行为不变。

**Non-Goals:**

- 迁移 `work_status_dialog.xml` 外层 `@mipmap` 对话框背景至 `FrostedGlassDialog`。
- 修改 `WorkStatusDialog` 窗口尺寸、标题文案或 `showButton` 逻辑。
- 为浅色弹窗单独引入 `frosted_glass_blur_tint_light`（已尝试并回退，统一使用 `frosted_glass_blur_tint`）。

## Decisions

### 1. Shared machine-status components (`MachineStatusChrome`)

**Choice:** 新增 `MachineStatusGaugeCard`、`MachineStatusStatusTile`、`MachineStatusChrome`（`MONITOR` / `DIALOG` 预设），两页布局仅通过 `app:machineStatusVariant` 与 dimension style 区分。

| 属性 | Monitor | Dialog (more monitor) |
| --- | --- | --- |
| 卡片背景 | `transparent` | `frosted`（blur） |
| 标签色 | 白色 | 黑色（浅色模糊底） |
| Checkbox | `check_box_warn_show` | `highlight_check_box` |
| 仪表刻度 | 白色（style 默认） | 黑色（`machine_status_dialog_circle_progress`） |
| stack panel fill | 否 | 否 |

**Rationale:** 消除重复；dialog 与 monitor 的 typography 按底图对比度分别定稿，不再强制弹窗白字。

### 2. Frosted fill = backdrop blur, not solid panel on light backgrounds

**Choice:** `FrostedGlassCard` 在 `drawFill=true` 时挂载内部 `BlurView`；blur 成功且 `frostedGlassStackPanelFill=false`（默认）时，`contentContainer` **不**绘制 `FrostedGlassPanelDrawable`，仅 blur + `frosted_glass_blur_tint`。

**Rationale:** 固定深色渐变（`#73121214`）叠在浅色壁纸 → 灰色色块；实时模糊才能呈现黄白毛玻璃。blur 失败时仍 fallback 到 `PanelDrawable`。

### 3. `frostedGlassStackPanelFill` — dialog prompt only

**Choice:** 新属性 `app:frostedGlassStackPanelFill` 默认 `false`。仅 `dialog_frosted_glass_prompt.xml` 的根 `FrostedGlassCard` 设为 `true`，在 blur 之上恢复 `PanelDrawable`，匹配重构前 `FrostedGlassOverlayHost.applyGlassPanelStyle` 浓度。

**Rationale:** 全卡片启用 stack fill 会使 Settings/Monitor 等独立 `FrostedGlassCard` 发灰；more monitor 机台状态卡片**不得**启用（与 `FrostedGlassDialog` 提示壳区分）。

### 4. `work_status_dialog` BlurTarget

**Choice:** 黄白 `@mipmap` 壁纸层外包 `BlurTarget`（`@+id/frosted_glass_blur_target`）；内容层（含 `MachineStatusDialogFragment`）为兄弟节点，卡片通过 `FrostedGlassBlurSupport.findLocalBlurTarget` 在同窗口采样。

**Rationale:** `WorkStatusDialog` 为独立 Dialog 窗口，不得 fallback 到 Activity `android.R.id.content`（跨窗口 blur 失败）。

### 5. Single-layer `FrostedGlassDialog`

**Choice:** `dialog_frosted_glass_prompt.xml` 移除外层 `BlurView`；`FrostedGlassOverlayHost` 不再 `setupLiveBlur`；输入 dialog IME 锚点改为 `@+id/frosted_glass_content`。

**Rationale:** 外层 + 内层双 BlurView 导致雾化过重、质量变差。

### 6. Full-card blur padding migration

**Choice:** 启用 backdrop blur 时，将卡片 padding 迁移至 `contentContainer`，使 `BlurView` 铺满圆角区域（与安全提示页双层边框修复一致）。

### 7. Status tile symmetric horizontal inset

**Choice:** `MachineStatusStatusTile` 左右 padding 均使用 `frosted_glass_content_padding`（24dp），标签与复选框距卡片左右缘等距。

### 8. Buttons unchanged from original proposal

**Choice:** `work_status_btn_confirm` → `FrostedGlassButton` primary；`more_monitor_btn` → `FrostedGlassButton` default rounded，移除 `pressure_monitoring_btn_*` 工艺色背景。

## Risks / Trade-offs

- **[Blur 在模拟器/低端机失败]** → fallback 为 `PanelDrawable`，浅色底仍可能偏灰；log tag `FrostedGlassBlur`。
- **[Dialog tint 在浅色底略偏灰]** → 使用全局 `frosted_glass_blur_tint`，未单独 light 变体；可后续微调 alpha。
- **[共享组件影响 Monitor]** → `fragment_machine_status.xml` 已迁移至同一组件；Monitor 保持 transparent，已验证无灰色填充。

## Migration Plan

1. 抽取 `MachineStatus*` 组件并迁移 Monitor + dialog 布局。
2. 实现 `FrostedGlassBlurSupport` 与 `FrostedGlassCard` backdrop blur。
3. `work_status_dialog` 增加 `BlurTarget`；迁移按钮。
4. 统一 `FrostedGlassDialog` prompt 为单层卡片 + `frostedGlassStackPanelFill`。
5. `make sync` 验证：Monitor、快速模式更多监测、`FrostedGlassDialog` 提示弹窗、安全提示页卡片。
6. 清理 `pressure_monitoring_btn_*`（`reminder_btn_confirm_border` 仍被 `dialog_reminder.xml` 使用）。

## Open Questions

- 无阻塞项。更多监测入口 default glass 是否需工艺色 primary 变体可在 QA 后决定。
