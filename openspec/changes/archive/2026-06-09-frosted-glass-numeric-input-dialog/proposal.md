## Why

工程师模式与高级设置中约 30 项工艺/设备参数仍通过 `InputDialogFragment`（独立 `DialogFragment` + 截图模糊壳）录入数字。该实现与已迁移的 `FrostedGlassDialog` 视觉风格割裂；更关键的是，软键盘弹出时会触发宿主 Activity 的 `adjustResize` 行为，导致背景界面被压缩、布局错位，关闭弹窗后仍可能残留 inset 高度。`migrate-prompt-dialogs-to-frosted-glass` 已明确将数字输入列为下一批迁移目标，现文本输入、WiFi 密码等场景已验证 FrostedGlass 壳层可行，应继续完成数字输入统一。

## What Changes

- 新增 `FrostedGlassNumericInputDialog` 薄 wrapper 与共享 body 布局 `frosted_glass_body_numeric_input.xml`（数字输入框、可选描述文案、可选 ± 步进按钮），挂载于 `FrostedGlassDialog.prompt(...).customBodyView(...)`。
- 将 `InputDialogBuilder`（工程师模式 ~22 项数字参数）与 `SettingInputDialogBuilder`（高级设置 ~10 项数字参数）从返回 `InputDialogFragment` + `FragmentManager.show()` 改为直接调用 FrostedGlass numeric wrapper（与 `FrostedGlassTextInputDialog` 一致）。
- 键盘策略：弹窗显示期间对宿主 Activity 临时设置 `SOFT_INPUT_ADJUST_NOTHING`，overlay 卡片通过 IME WindowInsets 平移（而非 resize 背景）；关闭时恢复宿主 softInputMode 并清理 IME inset，消除背景压缩与残留高度。
- 保留现有校验逻辑（`EngineerDataCheck`、高级设置校验）、步进语义（整数 ±1 / 小数 ±0.1）、单位标题格式、默认值格式化与 confirm/cancel 行为。
- **删除** `InputDialogFragment` 及其 legacy 布局/资源（`dialog_input` 相关 binding、截图 RenderScript 模糊、独立 Dialog 窗口键盘 hack）。
- 更新 OpenSpec：`frosted-glass-dialog` 移除数字输入豁免；`engineer-mode-common-params` 扩展至数字参数。

**明确不在本次范围：**

- 告警类弹窗（`WarnDialogUtil` 等）
- `ReminderExactDialog`、`EngineerModeEntryTipsDialog`、`CNCExitDialog`、`WorkStatusDialog`
- `InputNumberPicker` / 工艺库 picker 类组件（非参数弹窗场景）

## Capabilities

### New Capabilities

- `frosted-glass-numeric-input-dialog`: 共享数字参数输入 FrostedGlass body + wrapper API、键盘/inset 策略、步进与校验集成约定

### Modified Capabilities

- `frosted-glass-dialog`: 移除 `InputDialogFragment` 数字输入豁免；补充 numeric-input custom-body 模式与键盘不压缩背景的要求
- `engineer-mode-common-params`: 数字工艺参数弹窗 SHALL 使用 FrostedGlass numeric wrapper，不再使用 `InputDialogFragment`

## Impact

- **Java**: 新增 `FrostedGlassNumericInputDialog`；重构 `InputDialogBuilder`、`SettingInputDialogBuilder`；更新工程师模式 fragment（`EngineerCuttingFragment`、`EngineerWashFragment`、`EngineerSpotWeldingFragment` 等）与 `AdvancedSettingFragment` 的调用方式（去掉 `FragmentManager.show()`）；`FrostedGlassOverlayHost` 或 wrapper 内增加 IME inset 处理；**删除** `InputDialogFragment`
- **布局/资源**: 新增 `frosted_glass_body_numeric_input.xml`；删除 `dialog_input` 相关 layout/drawable/binding
- **OpenSpec**: 新增 capability spec；delta `frosted-glass-dialog`、`engineer-mode-common-params`
- **行为**: 参数校验、Modbus 写入、ViewModel 更新路径不变；仅弹窗壳层与键盘交互改变
