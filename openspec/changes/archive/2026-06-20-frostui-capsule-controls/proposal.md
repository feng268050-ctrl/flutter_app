## Why

通用设置「显示与声音」卡片中，语言/单位/息屏时间/音效仍由 `ControlCapsule` + `RadioGroup`/`RadioButton` 组合实现，屏幕亮度由 `ControlCapsule` + 系统 `SeekBar` + 叠加 `TextView`/`ImageView` 实现。这些控件未纳入已落地的 `frostui.control`（Switch/Checkbox/线性 Slider），无法复用 Compose token、点击音与 `interop` 模式，且亮度行的叠色逻辑与布局耦合在 `CommonSettingsFragment` 中难以复用。在 `frost-ui` 分支上将红框内控件迁入 FrostUI，可延续设计系统闭环。

## What Changes

- 新增 `FrostSegmentedControl` + `FrostSegmentedControlView`：胶囊容器内互斥分段选择（对标 `ControlCapsule` + `RadioGroup`）。
- 新增 `FrostCapsuleSlider` + `FrostCapsuleSliderView`：粗胶囊填充式滑块，内置进度百分比与尾部图标叠色（对标亮度行 `SeekBar` + overlay）。
- 扩展 `frostui_control_*.xml`：分段控件与胶囊滑块的颜色、尺寸、文字样式 token（自 `control_capsule`、`radiobutton_*`、`capsule_seekbar_*` 迁入）。
- 迁移 `fragment_common_settings.xml` 红框内 5 行（语言、单位、屏幕亮度、息屏时间、音效）。
- **`fragment_screen_display.xml` / `ScreenDisplayFragment`**：经核实无当前 Tab 入口（逻辑已并入 `CommonSettingsFragment`）；本 change **不迁移**，layout/Fragment 可删或留档（实现阶段确认）。
- 更新 `CommonSettingsFragment` 绑定：由 `RadioGroup`/`SeekBar` API 改为 `FrostSegmentedControlView` / `FrostCapsuleSliderView` API。
- **BREAKING**：删除 `com.lasercyber.lws.ui.component.layout.ControlCapsule`（迁移后无引用）。
- 本 change **不含**：`fragment_screen_display.xml`（无入口，死代码）、`FrostSlider` 改造、Spinner/WheelView、其他页面的 `RadioButton`。

## Capabilities

### New Capabilities

- `frostui-capsule-controls`: 定义 `FrostSegmentedControl` 与 `FrostCapsuleSlider` 的 Compose API、XML interop、设计 token、点击音、叠色行为，以及通用设置页迁移与删除 `ControlCapsule` 的契约。

### Modified Capabilities

- `frostui-framework`: `frostui.control` 包扩展两个新原语；资源文件 `frostui_control_*` 增补 capsule 相关 token。

## Impact

- **源码**：扩展 `app/src/main/kotlin/com/lasercyber/lws/frostui/control/` 与 `interop/`；删除 `ControlCapsule.java`。
- **布局**：`fragment_common_settings.xml`（5 处控件替换）。
- **Java**：`CommonSettingsFragment.java` 绑定与亮度叠色逻辑简化。
- **资源**：新增/扩展 `frostui_control_colors.xml`、`frostui_control_dimens.xml`、`frostui_control_attrs.xml`。
- **分支**：仅 `frost-ui`；本阶段不合入 `dev`。
- **测试**：分段选择与胶囊滑块单元测试；通用设置页 emulator 视觉对比；`make sync` 验证语言/单位/亮度/息屏/音效交互。
- **非影响**：`FrostSwitch`、`FrostSlider`（高级设置）、`fragment_screen_display.xml` 不变。
