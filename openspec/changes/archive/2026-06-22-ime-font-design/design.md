## Context

- IME 键帽已用 Compose + `ImeGlassKeyBackground` / `ImePrimaryKeyShell` 实现 frosted glass；字号来自 `ime_dimens.xml`（如 `ime_key_primary_text_size` 28sp）。
- 输入经 `ImeFieldType` + `ImeFieldProfileRegistry` 驱动；Dialog 多为 Java + XML `EditText`。
- 设计文档 `docs/ime-font-design.md` v1 存在与代码不一致处（枚举名、SEND 示例、仅 Compose TextField 示例等）。

## Goals / Non-Goals

**Goals:**

- 键帽 UI 文字统一 **Inter**；精确输入内容统一 **JetBrains Mono**（按 Field Type）。
- Typography token 单点维护；Field Type → TextStyle 经 `ImeFontResolver`。
- Dialog EditText 与 Compose 键盘视觉一致。
- 保留现有 frosted glass 键帽 chrome（fill、border、ripple、spacing、primary Enter 橙色底）。

**Non-Goals:**

- 不调整 `frostPanelFill` / `frostPanelBorder` / `ImeKeyPressEffect` / `ime_key_gap` 等 glass 参数。
- 不引入 CJK 字体；拼音候选栏首版仍用系统 sans（文档说明）。
- 不替换矢量/Canvas 功能键图标为字体字符。

## Decisions

### D1: Inter（键帽 + Text 输入）+ JetBrains Mono（精确输入）

与 `docs/ime-font-design.md` 一致。键帽是 UI chrome；输入内容是数据。整盘 Mono 会破坏 HMI 统一感。

### D2: Typography 绑定 `ime_dimens.xml`

`ImeTypography` 从 `ime_dimens` 读取 sp，例如：

```kotlin
KeyLabel = TextStyle(
    fontFamily = ImeFontFamilies.Inter,
    fontWeight = FontWeight.Medium,
    fontSize = /* ime_key_primary_text_size */,
)
```

避免文档 30sp 与实现 28sp 双轨。若需调字号，只改 dimen。

### D3: 键帽 token 分层

| Token | 用途 | 字体 | 权重 | dimen |
|-------|------|------|------|-------|
| `KeyLabel` | 字母/数字/符号键 | Inter | Medium | `ime_key_primary_text_size` |
| `KeyHint` | secondary hint | Inter | Medium | `ime_key_secondary_hint_text_size` |
| `KeyPopup` | 长按弹出 | Inter | Medium | `ime_key_alternate_popup_text_size` |
| `ActionKeyLabel` | ABC/123/C/文字 Enter | Inter | SemiBold | `ime_key_enter_text_size` |
| `AccentKeyLabel` | ⌫/−/C 橙色文字 | Inter | Medium | `ime_key_primary_text_size` |

默认 Enter（`ic_ime_enter_filled`）**不**套用 ActionKeyLabel——仅图标，无字体变更。

### D4: `ImeFontResolver` API

```kotlin
fun inputTextStyleFor(type: ImeFieldType, passwordVisible: Boolean = true): TextStyle
fun keyLabelStyle(): TextStyle
fun keyHintStyle(): TextStyle
fun keyPopupStyle(): TextStyle
fun actionKeyLabelStyle(): TextStyle
fun accentKeyLabelStyle(): TextStyle
```

Password：`passwordVisible == false` → Inter 或系统默认（掩码 bullet）；`true` → Mono。

WiFi 与 Password 同规则。

Field Type 映射（与 `ImeFieldType.kt` 一致）：

| Type | 输入字体 |
|------|----------|
| Text | Inter |
| Number, SignedDecimal | Mono |
| Email, Uri | Mono |
| Password, WiFi | Mono（明文）/ 掩码见上 |

### D5: EditText 接入（Java）

新增小工具 `ImeFontTypeface`（或 `ImeFontResolver.applyTo(EditText, fieldType, passwordVisible)`）：

- `ResourcesCompat.getFont(context, R.font.inter_medium)` 等
- 在 Dialog `onCreate` / 绑定 `ImeOverlaySpec.fieldType` 时调用
- Password 显示切换时重新 apply

Compose 键帽在 `ImeKeyCap` / shell 层替换 `fontSize` + 默认 family 为 `style = ImeTypography.*`。

### D6: 字体文件与 license

```
res/font/inter_regular.ttf
res/font/inter_medium.ttf
res/font/inter_semibold.ttf
res/font/jetbrains_mono_regular.ttf
res/font/jetbrains_mono_medium.ttf
assets/licenses/fonts/INTER_OFL.txt
assets/licenses/fonts/JETBRAINS_MONO_OFL.txt
```

固定 TTF 权重；首版不用 variable font（RK3566 / Android 11 可维护性）。

### D7: 性能

`ImeFontFamilies` 为 `object` 单例；`TextStyle` token 为 `val` 常量；不在 recomposable 内重复 `FontFamily(...)`。

## Risks / Trade-offs

- **[Risk] EditText 与 Compose 键帽字体视觉微差** → 同 family + 同 medium weight + 同 sp dimen；联调 Process Parameter Name / Numeric / WiFi 弹窗。
- **[Risk] APK 体积** → 仅 5 个 TTF；文档记录预估增量。
- **[Risk] 误改 glass 样式** → 任务与验收明确「仅 TextStyle / Typeface」；PR 禁止动 `ImeGlassKeyBackground` 除非 bugfix。
- **[Trade-off] Email 用 Mono** → 可读性优先于「邮箱像句子」；文档保留后续改 Inter 的开关说明。

## Migration Plan

1. Phase 1：字体资源 + `ImeFontFamilies` + 编译
2. Phase 2：键帽 Compose 换 Inter（glass 不动）
3. Phase 3：Dialog EditText + Password 动态切换
4. Phase 4：目视微调（居中、符号可读性）

Rollback：移除 font 引用，恢复默认 `Text`/`EditText` typeface；无 schema 变更。

## Open Questions

- 拼音候选栏是否 Phase 2 后单独评估 Inter（当前 Non-Goal）。
- Email 是否在 Phase 4 后 A/B Inter vs Mono（产品确认）。
