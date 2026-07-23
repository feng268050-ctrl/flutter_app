# IME 字体方案设计：Inter + JetBrains Mono

**相关文档**

- `docs/ime-field-type-keyboard-design.md` — Field Type、键盘布局、Registry
- `openspec/changes/ime-font-design/` — 实施 proposal / design / tasks / specs

**实施约束（必须遵守）**

- **不改变**键盘 frosted glass 键帽视觉：`ImeGlassKeyBackground`、`ImePrimaryKeyShell` 的 fill / border / ripple / spacing / primary Enter 橙色底保持现状。
- 本方案 **仅** 调整 `TextStyle` / `EditText` Typeface，不修改 glass 参数或键帽 chrome 逻辑。
- Shift / Enter（默认矢量图标）/ Backspace 等 **继续** 使用 Canvas / VectorDrawable，不用字体 glyph 替代。

---

## 1. 背景

自定义 IME 用于工业 HMI：深色界面、Frosted Glass 背景、灰色 light-tone 键帽、橙色 primary 回车键。

**Field Type**（与 `ImeFieldType.kt` 一致）：

| 类型 | 说明 |
|------|------|
| `Text` | 普通英文文本 |
| `Number` | 整数 |
| `SignedDecimal` | 带符号 / 小数 |
| `Email` | 邮箱（Registry 已定义，Dialog 待接） |
| `Uri` | URI（Registry 已定义，Dialog 待接） |
| `Password` | 密码 |
| `WiFi` | WiFi 密码（独立 Profile） |

**字体方案首版范围**

- 键帽与拉丁输入内容：Inter + JetBrains Mono。
- 拼音候选栏（`ChineseGlobal`）：**暂用系统 sans**，不引入 CJK 字体（避免 APK 膨胀）。

---

## 2. 字体选型

### 2.1 Inter — 键帽与 Text 输入

- 来源：[rsms/inter](https://github.com/rsms/inter) 官方 release
- 用途：键帽 label、功能键文字、Dialog 标题/描述（IME 相关弹窗）、`ImeFieldType.Text` 输入内容
- 理由：高 x-height、屏幕阅读优化、与 Frosted Glass HMI 风格一致

### 2.2 JetBrains Mono — 精确输入

- 来源：[JetBrains/JetBrainsMono](https://github.com/JetBrains/JetBrainsMono) 官方 `fonts/` 或 release
- 用途：`Number` / `SignedDecimal` / `Email` / `Uri` / `Password`（明文）/ `WiFi`（明文）
- 理由：等宽、0/O/1/l/I 易区分，URI/参数类符号清晰

---

## 3. 设计目标

1. 提升键帽与输入内容的可读性、工业质感。
2. 字体策略与 `ImeFieldType` 对齐，便于扩展。
3. **不**改变 frosted glass 键帽 chrome。
4. **不**引入中文字体；**不**用字体替代 Shift/Enter/Backspace 图标。
5. Typography 单点维护，字号来自 `ime_dimens.xml`，避免双轨 sp。

---

## 4. 使用原则

### 4.1 键帽统一 Inter

字母、数字、符号、ABC / 123 / #+= / C 等 **键帽 UI** 均用 Inter（非输入结果本身）。

默认 Enter 为 **`ic_ime_enter_filled` 矢量图标**，不套文字 Typography。

### 4.2 输入框按 Field Type

| Field Type | 输入字体 | 说明 |
|------------|----------|------|
| `Text` | Inter | 自然阅读 |
| `Number`, `SignedDecimal` | JetBrains Mono | 数字、小数点、负号 |
| `Email`, `Uri` | JetBrains Mono | `@` `/` `.` 等符号 |
| `Password`, `WiFi` | 掩码：系统 bullet；**明文：Mono** | 随显示/隐藏动态切换 |

---

## 5. 字体文件

### 5.1 目录

```text
app/src/main/res/font/
├── inter_regular.ttf
├── inter_medium.ttf
├── inter_semibold.ttf
├── jetbrains_mono_regular.ttf
└── jetbrains_mono_medium.ttf

app/src/main/assets/licenses/fonts/
├── INTER_OFL.txt
└── JETBRAINS_MONO_OFL.txt
```

首版 **不** 引入 variable font、Light/Bold/Italic、Noto CJK。预计 APK 增量 **~1–2 MB**。

### 5.2 命名

Android 资源名小写 + 下划线，例如 `Inter-Medium.ttf` → `inter_medium.ttf`。

---

## 6. Typography Token（绑定 dimen）

字号 **必须** 引用 `ime_dimens.xml`，不在 Kotlin 中重复硬编码 sp。

| Token | 用途 | 字体 | 权重 | dimen |
|-------|------|------|------|-------|
| `KeyLabel` | 字母/数字/符号键 | Inter | Medium | `ime_key_primary_text_size`（28sp） |
| `KeyHint` | secondary hint | Inter | Medium | `ime_key_secondary_hint_text_size`（11sp） |
| `KeyPopup` | 长按弹出 | Inter | Medium | `ime_key_alternate_popup_text_size`（28sp） |
| `ActionKeyLabel` | ABC/123/文字 Enter | Inter | SemiBold | `ime_key_enter_text_size`（20sp） |
| `AccentKeyLabel` | ⌫/C/− 橙色文字 | Inter | Medium | `ime_key_primary_text_size` |
| `TextInputValue` | Text 输入框 | Inter | Medium | 与 Dialog EditText 现有 sp 对齐 |
| `MonoInputValue` | 精确输入框 | JetBrains Mono | Medium | 同上 |

---

## 7. 代码结构

```text
app/src/main/kotlin/com/lasercyber/lws/ime/theme/
├── ImeFontFamilies.kt    # Inter / Mono 单例 FontFamily
├── ImeTypography.kt      # TextStyle token（读 dimen）
├── ImeFontResolver.kt    # Field Type + Password visible → TextStyle
└── ImeFontTypeface.kt    # EditText Typeface 应用（Java Dialog）
```

### 7.1 `ImeFontFamilies`

```kotlin
object ImeFontFamilies {
    val Inter = FontFamily(
        Font(R.font.inter_regular, FontWeight.Normal),
        Font(R.font.inter_medium, FontWeight.Medium),
        Font(R.font.inter_semibold, FontWeight.SemiBold),
    )
    val Mono = FontFamily(
        Font(R.font.jetbrains_mono_regular, FontWeight.Normal),
        Font(R.font.jetbrains_mono_medium, FontWeight.Medium),
    )
}
```

（`R` = `com.lasercyber.lws.ui.R`）

### 7.2 `ImeFontResolver`

```kotlin
fun inputTextStyleFor(type: ImeFieldType, passwordVisible: Boolean = true): TextStyle
fun keyLabelStyle(): TextStyle
fun keyHintStyle(): TextStyle
fun keyPopupStyle(): TextStyle
fun actionKeyLabelStyle(): TextStyle
fun accentKeyLabelStyle(): TextStyle
```

Password / WiFi：`passwordVisible == false` → 掩码（系统 glyph，不强制 Mono）；`true` → Mono。

---

## 8. Compose 键帽应用

```kotlin
Text(
    text = displayPrimary,
    style = ImeTypography.KeyLabel,
    color = imeDefaultTextColor(),
    textAlign = TextAlign.Center,
)
```

**禁止** 为字体 rollout 修改 `ImeGlassKeyBackground` / `ImePrimaryKeyShell` 的 `frostPanelFill` / `frostPanelBorder` / ripple 参数。

---

## 9. Java / XML Dialog（EditText）

Dialog 多为 `FrostedGlass*Dialog.java` + XML `EditText`，须与 Compose 键帽一致：

```kotlin
// ImeFontTypeface.applyTo(editText, fieldType, passwordVisible)
ResourcesCompat.getFont(context, R.font.inter_medium)
ResourcesCompat.getFont(context, R.font.jetbrains_mono_medium)
```

| Dialog | Field Type | 字体 |
|--------|------------|------|
| `FrostedGlassTextInputDialog` | Text | Inter |
| `FrostedGlassNumericInputDialog` | Number / SignedDecimal | Mono |
| `FrostedGlassWifiPasswordDialog` | WiFi / Password | 掩码/明文规则 |

Password 👁 切换时 **重新 apply** Typeface。

---

## 10. 性能与 License

- `ImeFontFamilies` / `ImeTypography` 使用 `object` 单例；不在每个 Composable 内 `FontFamily(...)`。
- RK3566 / Android 11：字体非瓶颈；避免动画中重建 TextStyle。
- OFL 许可文件必须与 TTF 一并入库；不修改 reserved font name 后当作自有字体发布。

### APK 体积（§16）

入库 5 个 TTF（Inter Regular/Medium/SemiBold + JetBrains Mono Regular/Medium）未压缩合计约 **1.7 MB**；打包进 APK 后 gzip 压缩，实际增量约 **1–1.2 MB**，在 RK3566 可接受范围内。

---

## 11. 实施阶段（与 OpenSpec tasks 对齐）

| Phase | 内容 |
|-------|------|
| **1** | TTF + license + `ImeFontFamilies` + 编译 |
| **2** | 键帽 Inter（`ImeKeyCap` / popup / accent / 文字 Enter）；**glass 不动** |
| **3** | Dialog EditText + Password 动态 Mono |
| **4** | 目视微调（居中、符号可读性）+ 单测 + sync |

详见 `openspec/changes/ime-font-design/tasks.md`。

---

## 12. 验收标准

### 键帽

- 所有文字 label 为 Inter；glass / ripple / spacing 无回归。
- 默认 Enter 仍为实心矢量图标；Shift 仍为 Canvas 图标。

### 输入框

- Text → Inter；Number / SignedDecimal / Email / Uri / Password（明文）/ WiFi（明文）→ Mono。
- 键盘与 EditText 同场景字体一致。

### 稳定性

- RK3566 无输入卡顿；123/ABC 切换无字体闪烁；APK 增量可控。

---

## 13. 结论

```text
Inter：键帽、功能键文字、Text 输入、IME 相关 Dialog 文案
JetBrains Mono：Number、SignedDecimal、Email、Uri、Password/WiFi 明文
不变：frosted glass 键帽 chrome、矢量功能键图标、拼音候选区字体（首版）
```
