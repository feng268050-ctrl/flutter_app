## Why

Switch、Checkbox 与高级设置线性滑块（`ScaledSlider`）仍以 `com.lasercyber.lws.ui.component` 自研 View 分散实现，与已落地的 FrostUI（`border` / `card` / `dialog`）未统一。表单控件无法复用 Compose 设计 token、点击音注入与 `interop` 桥接模式，且与 `frostui` 依赖边界不一致。在 `frost-ui` 分支上将这些控件迁入 `frostui.control`，可在不扩大范围（不含 Select、FlankedSeekBar、快捷模式滚轮）的前提下完成设计系统闭环。

## What Changes

- 新增 `com.lasercyber.lws.frostui.control` 包：`FrostSwitch`、`FrostCheckbox`、`FrostSlider`（仅线性）及 `interop` View（`FrostSwitchView`、`FrostCheckboxView`、`FrostSliderView`）。
- 新增 `frostui_control_*.xml` 资源（attrs、colors、dimens、样式），从现有 `LwsSwitch` / `LwsCheckbox` / `ScaledSlider` token 迁入。
- **BREAKING**：删除 `ui.component.Switch`、`ui.component.Checkbox`、`ui.component.ScaledSlider`；相关 layout 类名改为 `frostui.control.interop.*`（无 `@Deprecated` wrapper）。
- **保留** `ui.component.ScaledSeekBar`（`FlankedSeekBar` / 工艺视频仍依赖）。
- 迁移 layout：
  - Switch：6 个文件（含 `activity_bluetooth.xml`）
  - Checkbox：5 个 layout
  - Slider：`fragment_advanced_setting.xml`（约 20 处）
- 同步更新 Java 绑定（`WifiActivity`、`BluetoothManagerActivity`、`AdvancedSettingFragment`、对话框与安全须知等）。
- 视觉验收：**逐像素**对齐现有控件（D12: A）；Switch/Checkbox 动画 200ms。
- 本 change **不含**：FrostSelect、FlankedSeekBar、GearPick、Icons/Material Icons、RadioButton 替换、工程师 Popup 主题。

## Capabilities

### New Capabilities

- `frostui-control-primitives`: 定义 `frostui.control` 包内 Switch、Checkbox、线性 Slider 的 Compose API、XML interop、设计 token、点击音、无障碍与迁移后删除旧 `ui.component` 类的契约。

### Modified Capabilities

- `frostui-framework`: 顶层包结构从三层扩展为包含 `control` 第四层；`control` 依赖 `border`；`frostui` 仍不得依赖 `ui`/`ai`。

## Impact

- **源码**：新增 `app/src/main/kotlin/com/lasercyber/lws/frostui/control/`；删除 `Switch.java`、`Checkbox.java`、`ScaledSlider.java`；保留 `ScaledSeekBar.java`。
- **布局**：11 个 layout 文件类名与样式引用变更（见 design.md）。
- **资源**：`frostui_control_attrs.xml`、`frostui_control_colors.xml`、`frostui_control_dimens.xml`；自 `attrs.xml` 移除旧 Switch/Checkbox/ScaledSlider styleable（与删类同期）。
- **文档**：`docs/frostui-control-primitives-design.md` 为决策来源；须修订 `docs/frostui-compose-refactor-design.md` 中「仅三层」描述。
- **分支**：仅 `frost-ui`；本阶段不合入 `dev`。
- **测试**：控件回调单元测试；迁移页 emulator 视觉对比；`make sync` 验证通用设置、高级设置、WiFi/蓝牙、安全须知、对话框。
- **非影响**：`FlankedSeekBar`、`WheelView`、`Spinner`、`FrostedGlassPopupMenu` 行为与 API 不变。
