## Why

自定义 IME 键帽与输入框目前使用系统默认字体，在工业 HMI 深色 Frosted Glass 场景下可读性与字符辨识度不足（数字、URI、密码明文等）。`docs/ime-font-design.md` 已定义 **Inter + JetBrains Mono** 方案，但尚未接入代码。现需在 **不改变键盘 frosted glass 键帽视觉**（fill/border/ripple/间距）的前提下，统一字体策略并与 `ImeFieldType` 对齐。

## What Changes

- 修订 `docs/ime-font-design.md`：对齐代码枚举名、dimen 字号、WiFi 类型、EditText 接入路径、Password 动态切换；明确 frosted glass 非目标。
- 引入 Inter / JetBrains Mono 字体资源（5 个 TTF + OFL license）。
- 新增 `ime/theme/ImeFontFamilies.kt`、`ImeTypography.kt`、`ImeFontResolver.kt`；Typography **引用** `ime_dimens.xml`，不重复硬编码 sp。
- 键帽 Compose `Text` 统一 Inter（label / hint / popup / 功能键文字）；**不**改 Shift/Enter/Backspace 等 Canvas/Vector 图标。
- 输入框按 `ImeFieldType` 切换字体：Text → Inter；Number / SignedDecimal / Email / Uri / Password（明文）/ WiFi → JetBrains Mono。
- Java/XML Dialog 的 `EditText` 同步设置 `Typeface`（Text / Numeric / WiFi Password 等已接入 IME 的弹窗）。
- 单元测试：`ImeFontResolver` 映射；键帽/输入框字体不触发 glass 样式回归。

**明确不在本次范围：**

- 修改键帽 frosted glass fill/border/ripple/primary 配色或 `ImeGlassKeyBackground` 行为
- 引入中文字体或改造拼音候选区字体
- 用字体 glyph 替代 Shift / Enter / Backspace 图标
- 全 App Frost Dialog 标题全局换 Inter（仅 IME 相关输入弹窗与键盘）

## Capabilities

### New Capabilities

- `ime-font-typography`: Inter/Mono 资源、Typography token、Field Type 字体解析、键帽与输入框字体应用规则

### Modified Capabilities

- `frosted-glass-dialog`: 文本输入 Dialog 的 EditText 按 `ImeFieldType.Text` 使用 Inter
- `frosted-glass-numeric-input-dialog`: 数值输入 EditText 使用 JetBrains Mono
- `wifi-password-connect-dialog`: WiFi/Password 明文使用 JetBrains Mono；掩码态保持系统 password glyph

## Impact

- **资源**: `app/src/main/res/font/`（5 TTF）、`assets/licenses/fonts/`（OFL）
- **Kotlin 新增**: `com.lasercyber.lws.ime.theme.*`
- **Kotlin 修改**: `ImeKeyCap`、`ImeEnterKey`（仅文字 Enter 配置）、`ImeAlternatePopup`、`ImePinyinCandidateBar`（候选区暂保持系统字体，文档注明）
- **Java/XML 修改**: `FrostedGlassTextInputDialog`、`FrostedGlassNumericInputDialog`、`FrostedGlassWifiPasswordDialog` 及相关 layout
- **文档**: `docs/ime-font-design.md`、`docs/ime-field-type-keyboard-design.md` 交叉引用
- **APK**: 预计字体增量 ~1–2 MB
- **测试**: JVM 单测 + emulator 目视（键帽 glass 不变、字体可读）
