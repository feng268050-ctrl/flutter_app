## Why

HMI 输入仍依赖系统软键盘与 `FrostedGlassImeCoordinator` 协调层，存在视觉与 frostui 不一致、OEM 键盘行为不可控（回车文案、布局）、以及 overlay 样板代码重复等问题。产品要求按 **真正 IME 标准** 在 `com.lasercyber.lws.ime` 内实现 **应用内自定义键盘**（Compose + 雾化玻璃键帽），支持多键盘种类、语言驱动布局、可配置回车键、字母长按三选一悬浮条，并与现有 FrostedGlass overlay 输入场景集成。

## What Changes

- 新增 `com.lasercyber.lws.ime` 包（与 `frostui` 同级）：`core`（session、inset）、`engine`（InputConnection 式文本提交、EditorAction）、`keyboard`（布局模型、三种键盘、长按 popup）、`compose`（`ImeKeyboardPanel`、`ImeHost`）、`interop`（View/EditText 桥接）、`ImeRegistry`。
- 实现 **三种键盘**：中文全局键盘、英文全局键盘、数字键盘（0–9）；根据当前应用语言（`SystemSettingUtils.getLanguage()` / Common Settings Language）自动选择中/英全局键盘；数字字段自动使用数字键盘。
- **全局键盘布局**：上方字母区参照真机 QWERTY（含 shift、退格、字母键左上角第二功能符号，见图一）；**最底行固定 5 键**（见图三）：`123`/`abc` 模式切换、空格、逗号/句点、 `@`、**可自定义显示的回车键**。
- **数字键盘布局**：参照真机当前数字区（0–9 及必要符号/退格/回车）。
- **长按交互**：任意字母键长按弹出悬浮选择条，展示 **大写 / 第二功能 / 小写** 三项（见图二），滑动或点击选择后提交对应字符。
- **回车键**：`ImeEnterKeyConfig` 支持 **文本、图标或二者组合** 作为 Enter 键面显示；Enter 键 **始终** 使用 `FrostButtonVariant.PRIMARY`（橘黄 primary 按钮），action 可配置（Done / Connect 等）。
- 键盘键帽使用 **`frostui.card.FrostButton`**（DEFAULT glass + 按下效果）；**回车键**使用 **`FrostButtonVariant.PRIMARY`**（橘黄 primary）。
- 显示自定义键盘时 **隐藏系统 IME**（`SOFT_INPUT_ADJUST_NOTHING` + 不调用 `showSoftInput`）；`ImeController` 改为抬升 overlay 以适配 **应用内键盘面板高度**（非系统 IME inset）。
- 迁移 `FrostedGlassImeCoordinator` → `ImeController`；`FrostPromptConfig.imeConfig`；输入 wrapper 与 `FrostNumericStepper` ± 按钮 FrostButton 化。
- 新增 OpenSpec capabilities：`ime-overlay-input`、`ime-custom-keyboard`；更新 `frosted-glass-dialog`、`frosted-glass-components`。

**明确不在本次范围：**

- 独立系统级输入法 APK（可后续评估 `InputMethodService`，本 change 以 **应用内 IME 面板** 为交付形态，API 对齐 IME 标准便于升级）
- 完整拼音/仓颉等中文组词引擎（中文全局键盘首版为与真机一致的 **字母+符号布局**；中文输入语义由后续 input method 扩展）
- WiFi/工程师/Modbus 业务校验逻辑迁入 `ime`
- 新建 `:ime` Gradle 模块

## Capabilities

### New Capabilities

- `ime-overlay-input`: overlay session、宿主不 resize、卡片/键盘面板抬升、dismiss 清理、`ImeRegistry` 钩子
- `ime-custom-keyboard`: 三种键盘种类、语言选择、布局、长按 popup、可配置回车、Frost 键帽视觉与输入引擎

### Modified Capabilities

- `frosted-glass-dialog`: 输入 overlay 使用 `ImeConfig` + 应用内自定义键盘
- `frosted-glass-components`: 键盘 Enter PRIMARY 橘黄；步进 ± FrostButton
- `wifi-password-connect-dialog`: Connect 提交改为自定义 IME 回车键（不再依赖 OEM 软键盘 label）
- `wifi-password-connect-dialog`: Connect 提交改为自定义 IME 回车键显示「连接」并触发同一 submit 路径（不再依赖 OEM `setImeActionLabel`）

## Impact

- **Kotlin 新增**: `app/src/main/kotlin/com/lasercyber/lws/ime/**`（含 `keyboard/`、`engine/`）
- **资源**: 键盘 dimen/color 可复用 `frostui_*` token；回车/模式切换图标
- **Manifest**: 无需 InputMethodService（首版）；`windowSoftInputMode` 策略由 `ImeController` 统一管理
- **Java/Kotlin 修改**: 输入 dialog wrapper、`FrostUiDialogBridge`、`FrostPromptConfig`、`FrostNumericStepper`
- **语言**: 读取 Common Settings 当前语言决定 `KeyboardKind.EnglishGlobal` vs `ChineseGlobal`
- **文档**: `docs/ime-compose-refactor-design.md` 同步扩展
- **测试**: 布局单测、长按 popup 逻辑单测、emulator 全键盘种类与 overlay 联调
