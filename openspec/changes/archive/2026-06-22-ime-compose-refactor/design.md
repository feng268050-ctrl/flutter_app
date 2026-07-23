## Context

当前 `FrostedGlassImeCoordinator` 仅协调 **系统软键盘** inset，无法控制键帽视觉、回车文案、中英布局或数字区。产品提供真机参考（图一 QWERTY+第二功能、图二长按三选一 popup、图三简化底行 + 白键布局）并要求：

1. 按 IME 标准开发，**回车键可自定义显示**
2. 根据当前语言选中/英全局键盘
3. 三种键盘：中文全局、英文全局、数字 0–9
4. 字母长按：悬浮 **大写 / 第二功能 / 小写**
5. 全局底行：`123`/`abc`、空格、逗号/句点、`@`、回车（5 键）；上方参照真机

`frostui` 已有 `FrostButton`（PRIMARY 橘黄、DEFAULT glass、按下+点击音）。详见 `docs/ime-compose-refactor-design.md`。

## Goals / Non-Goals

**Goals:**

- `com.lasercyber.lws.ime` 与 `frostui` 同级，交付 **应用内 Compose 自定义键盘**（首版），API 对齐 Android IME 概念（`ImeInputConnection`、`ImeAction`、`ImeEnterKeyConfig`）。
- 三种 `KeyboardKind`：`EnglishGlobal`、`ChineseGlobal`、`Numeric`；语言由 **`ImeLanguageProvider`**（app 注册，默认读 `SystemSettingUtils.getLanguage()`）决定全局字母键盘种类。
- 全局键盘：上 3 行字母区 + shift/退格（参照图一第二功能角标）；底行 5 键（参照图三）。
- 数字键盘：0–9 网格 + 退格 + 回车（参照真机数字区）。
- 字母 **长按** 弹出三列 popup（大写 | 第二功能 | 小写），支持滑动选择（参照图二）。
- **回车键** 通过 `ImeEnterKeyDisplay` 支持 **文本 / 图标 / 二者**；Enter **始终 PRIMARY 橘黄**；WiFi 等场景可配 Connect 文本。
- 键帽 **`FrostButton` DEFAULT**；overlay 显示时 **隐藏系统 IME**，`ImeController` 按 **面板高度** 抬升卡片。
- 保留 `ImeRegistry` frost 副作用注入；`FrostPromptConfig.imeConfig` 集成。

**Non-Goals:**

- 首版不注册系统 `InputMethodService`（API 预留 `ImeServiceBridge`）。
- 不完整中文拼音组词引擎。
- 业务校验、Modbus 写入。

## Decisions

### 1. 交付形态 — 应用内 IME 面板（非系统 IME 首版）

**决定：** 在 Activity/overlay 底部 compose **`ImeKeyboardPanel`**，focus 时 `ImeController.showCustomKeyboard()` 替换 `InputMethodManager.showSoftInput`。

**理由：** 焊机 HMI 单应用、可控设备；无需用户安装/select 输入法；与 overlay 抬升、Frost 视觉一体。

**备选：** `InputMethodService` — 标准但集成成本高，Phase 2+ 可选。

**IME 标准对齐：**

```kotlin
interface ImeInputConnection {
    fun commitText(text: CharSequence)
    fun deleteBackward(codePointCount: Int = 1)
    fun performEditorAction(action: ImeAction): Boolean
}

data class ImeEnterKeyConfig(
    val label: String? = null,
    val iconRes: Int? = null,
    val action: ImeAction = ImeAction.Done,
)
```

### 2. 键盘种类与语言

**决定：**

```kotlin
enum class KeyboardKind { EnglishGlobal, ChineseGlobal, Numeric }

enum class KeyboardMode { Alpha, Numeric }  // 底行 123/abc 切换，仅 Global 有效
```

| 条件 | 初始 `KeyboardKind` |
|------|---------------------|
| 输入框 `inputType` 为数字类 | `Numeric` |
| 应用语言为中文（`zh*`） | `ChineseGlobal` |
| 否则 | `EnglishGlobal` |

中/英全局键盘 **键位布局相同**（真机 QWERTY + 第二功能表），差异为：默认字母大小写策略、底行 `abc` 标签文案、后续可扩展中文输入引擎 hook。语言变化时若键盘已显示，**热切换** layout definition。

**语言来源：**

```kotlin
// ImeRegistry.kt
var languageProvider: (() -> Locale)? = null  // app 注册 SystemSettingUtils.getLanguage()
```

### 3. 布局定义 — 声明式 KeyDef

**决定：** `ime/keyboard/layout/` 用数据类描述行/键，不写死 Composable：

```kotlin
data class KeyDef(
    val id: KeyId,
    val primary: String,           // 短按输出
    val secondary: String? = null, // 长按中间项 / 角标
    val widthWeight: Float = 1f,
    val isLetter: Boolean = false,
)

// 第二功能表示例（与图一一致）
// Q→1, W→2, … P→0; A→~, S→!, …; Z→(, … M→/
```

**EnglishGlobal / ChineseGlobal** 共享 `GlobalQwertyLayout.rows`（3 行字母 + shift/backspace 行）；**Numeric** 使用 `NumericLayout.rows`（0–9）。

**Global 底行（5 键，图三）：**

| 键 | 功能 |
|----|------|
| `123` / `abc` | `KeyboardMode` 在 Alpha ↔ Numeric 间切换（Numeric 时整盘切到 `KeyboardKind.Numeric` 布局，或内嵌数字子布局 — **决定：切换为 Numeric 键盘种类，abc 切回语言对应 Global**） |
| 空格 | 提交 U+0020 |
| `,` / `.` | 短按 `,`；长按或 popup 选 `.`（或单键 toggle — **首版：短按逗号，双击/长按 popup 含句点**；spec 写短按逗号、第二功能句点） |
| `@` | 提交 `@` |
| 回车 | `ImeEnterKeyConfig`；**FrostButton PRIMARY** |

**上方第三行（图一）：** Shift | Z–M | Backspace。

### 4. 长按 popup — 字母三选一

**决定：** `ImeKeyPopup` Composable，锚定在按键上方：

```
[  A  ] [  ~  ] [  a  ]   ← 大写 | 第二功能 | 小写
         ▲
        key
```

- **触发：** `detectTapGestures(onLongPress)` + 字母键 `isLetter == true`。
- **交互：** 长按出现；手指 slide 高亮项；抬手 commit 选中项；取消滑出 dismiss。
- **非字母键：** 无三列 popup（符号键可有 secondary-only popup 可选，首版仅字母）。

**实现：** `ime/keyboard/popup/ImeLetterPopup.kt` + `ImePopupState` 单例 per keyboard。

### 5. 可自定义回车键（文本 / 图标 / PRIMARY）

**决定：** `ImeConfig.enterKey: ImeEnterKeyConfig` 由 wrapper 传入。Enter 键 **永远是 PRIMARY 橘黄 `FrostButton` 壳**；键面内容通过 `display` 配置，**文本与图标至少提供其一**（均未提供时使用默认 return 图标）。

```kotlin
data class ImeEnterKeyConfig(
    val display: ImeEnterKeyDisplay,
    val action: ImeAction = ImeAction.Done,
)

/** Enter 键面：文本、图标、或二者并存；渲染层统一 PRIMARY。 */
sealed interface ImeEnterKeyDisplay {
    /** 仅文本，如 WiFi「连接」 */
    data class Text(val label: String) : ImeEnterKeyDisplay
    /** 仅图标，如 return 箭头、chevron */
    data class Icon(
        @DrawableRes val iconRes: Int,
        val contentDescription: String? = null,
    ) : ImeEnterKeyDisplay
    /** 图标 + 文本（可选，如 icon 在左 label 在右） */
    data class TextAndIcon(
        val label: String,
        @DrawableRes val iconRes: Int,
        val contentDescription: String? = null,
    ) : ImeEnterKeyDisplay
    /** 默认 return 图标（Done 场景） */
    data object Default : ImeEnterKeyDisplay
}
```

| 场景 | `display` | `action` |
|------|-----------|----------|
| 文本/数字输入 | `Default` 或 `Icon(return)` | `Done` |
| WiFi 密码 | `Text(connectString)` | `Custom(CONNECT)` |
| 仅需图标确认 | `Icon(chevron)` | `Go` |

**渲染：** `ime/compose/ImeEnterKey.kt` — 复用 `FrostButton` 的 PRIMARY fill/border/clickable 逻辑，键面 slot 按 `display` 渲染 `Text` / `Icon` / 二者；**禁止** Enter 使用 DEFAULT/SECONDARY variant。

```kotlin
@Composable
fun ImeEnterKey(
    config: ImeEnterKeyConfig,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // variant = PRIMARY 固定；content 来自 config.display
}
```

不再使用 `EditText.setImeActionLabel` 依赖 OEM 键盘。

### 6. 视觉 — FrostButton 键帽

**决定：**

| 键类型 | Variant |
|--------|---------|
| 普通字母/符号 | `DEFAULT`（dark glass，参照图一深灰键） |
| 回车 | `PRIMARY`（橘黄） |
| 步进 ±（NumericStepper） | `DEFAULT` |

`ime/compose` **允许依赖 `frostui.card`** 用于键帽（仅 UI 层）；`ime/core`、`ime/engine` 仍不依赖 frostui。

**按下效果：** 复用 `FrostButton` clickable + glass border；可选 `Modifier.graphicsLayer { alpha = if (pressed) 0.85f }` 增强反馈。

**角标：** 键帽内 `Box` 左上角小字 `secondary`（图一样式）。

### 7. Overlay 集成 — 面板高度替代 IME inset

**决定：** `ImeController` 扩展：

```kotlin
fun showCustomKeyboard(panelHeightPx: Int)
fun hideCustomKeyboard()
```

- attach 时仍 `SOFT_INPUT_ADJUST_NOTHING` + `hideSoftInputFromWindow`
- 卡片抬升使用 **`max(panelHeight, 0)`** 而非系统 IME inset（系统 IME 为 0）
- `ImeRegistry.onKeyboardShown(activity, heightPx)` 在面板展开后触发 backdrop refresh

`ImeHost` 结构：

```
Column {
  dialogCard()
  ImeKeyboardPanel(...)  // 固定 bottom，高度 ime_keyboard_height
}
```

### 8. frostui 依赖边界（修订）

| 模块 | 依赖 |
|------|------|
| `ime/core`, `ime/engine`, `ime/keyboard` | 无 frostui |
| `ime/compose` | frostui（FrostButton 键帽）、ime/core |
| `frostui/control`, `frostui/dialog` | ime |

### 9. 与现有 wrapper 迁移

- `FrostedGlassTextInputDialog` → `imeConfig(enterKey=Done)` + custom keyboard
- `FrostedGlassNumericInputDialog` → 自动 `KeyboardKind.Numeric`
- `FrostedGlassWifiPasswordDialog` → `enterKey=Connect` + 无 on-screen Connect
- 删除对 `InputMethodManager.showSoftInput` 的依赖（numeric 仍用 `EditText` 显示值，键盘为 custom panel）

## Risks / Trade-offs

- **[Risk] 中文全局无拼音引擎** → 首版与英文同布局，文档标明；后续 `ime/engine/pinyin` 扩展。
- **[Risk] 长按 popup 与滑动冲突** → 字母键区分 tap vs long-press threshold 300ms；popup 捕获 pointer。
- **[Risk] 面板高度与 blur backdrop** → 面板稳定高度 token `@dimen/ime_keyboard_height`；展开后 refresh backdrop。
- **[Risk] EditText 与 Compose 键盘双轨** → `ImeInputConnection` 适配 `Editable` / `TextFieldState`。
- **[Trade-off] ime/compose 依赖 frostui** → 键帽视觉统一，core 仍可单测 layout 数据。

## Migration Plan

1. **Phase 1 — core + engine**：`ImeController` 平移、面板高度抬升、`ImeInputConnection`。
2. **Phase 2 — keyboard 数据层**：三种 layout KeyDef、第二功能表、语言 provider。
3. **Phase 3 — Compose UI**：`ImeKeyboardPanel`、底行 5 键、Numeric 盘、FrostButton 键帽、PRIMARY 回车。
4. **Phase 4 — 长按 popup**：字母三选一 + 滑动选择。
5. **Phase 5 — overlay 集成**：`imeConfig`、wrapper 迁移、NumericStepper ± FrostButton、验收。
6. **Phase 6 — 清理**：删 `FrostedGlassImeCoordinator`、OEM IME 路径。

## Open Questions

- 中文全局键盘是否在首版增加「中/英」软切换键（图一底行）还是完全由系统语言设置驱动 — **当前：仅语言设置驱动，底行无 中/英 键（图三）**。
- 逗号/句点单键：短按逗号、长按 popup 仅 `.` 还是双字符 toggle — **首版：角标显示 `.`，短按 `,`，长按进入含 `.` 的 popup**。
