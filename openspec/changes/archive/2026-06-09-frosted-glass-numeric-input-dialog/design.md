## Context

工程师模式（`InputDialogBuilder`）与高级设置（`SettingInputDialogBuilder`）约 30 项数字参数仍通过 `InputDialogFragment` 录入。该组件为独立 `DialogFragment` 全屏窗口，自带 RenderScript 截图模糊、BlurView 毛玻璃与大量键盘 workaround（`SOFT_INPUT_ADJUST_PAN`、裁剪背景 Bitmap、`resetHostWindowAfterKeyboard` 等）。文本输入、WiFi 密码、日期/时间 picker 等已在 `migrate-prompt-dialogs-to-frosted-glass` 中迁移至 `FrostedGlassDialog` + 薄 wrapper 模式；数字输入被明确留作下一批。

当前痛点：

1. **视觉割裂**：legacy 深色卡片 + 独立 Dialog 动画，与 FrostedGlass 不一致。
2. **键盘压缩背景**：`DialogFragment` 与宿主 Activity 双窗口并存；即使 Dialog 侧设 `ADJUST_PAN`，宿主 Activity 仍可能因 `adjustResize` 被 IME 压缩，关闭后 inset 残留导致背景界面高度错位。

`FrostedGlassDialog` 使用 in-window overlay（`FrostedGlassOverlayHost.attachOverlay` 将 overlay 加到 Activity `content` root），live BlurView 模糊，无独立 Dialog 窗口。WiFi 密码（`FrostedGlassWifiPasswordDialog`）已验证 EditText + IME 可在 FrostedGlass 壳内工作，但未系统处理 IME inset 平移。

## Goals / Non-Goals

**Goals:**

- 统一数字参数弹窗为 `FrostedGlassDialog` + `FrostedGlassNumericInputDialog` wrapper
- 软键盘弹出时**不压缩**宿主背景界面；overlay 卡片随 IME 平移保持输入区可见
- 保留校验、步进（±1 / ±0.1）、单位标题、描述文案、默认值格式化、confirm/cancel 语义
- 删除 `InputDialogFragment` 及 legacy layout/binding
- Builder 调用方式与 `FrostedGlassTextInputDialog` 对齐（直接 `show`，不再 `FragmentManager.show()`）

**Non-Goals:**

- 告警弹窗、ReminderExactDialog、WorkStatusDialog 等已排除项
- `InputNumberPicker` / 工艺库 wheel picker
- 为 FrostedGlass 泛型壳增加内置 numeric 模式（仍走 custom body + wrapper）
- 修改 `EngineerDataCheck` 或 Modbus 写入逻辑

## Decisions

### 1. Wrapper API — `FrostedGlassNumericInputDialog`

**决定：** 新增 `FrostedGlassNumericInputDialog`，模式对齐 `FrostedGlassTextInputDialog` / `FrostedGlassWifiPasswordDialog`：

```java
FrostedGlassNumericInputDialog.show(context, title, config, listener);
```

`config` 封装：`defaultInput`、`descText`、`inputType`（整数/小数/有符号整数）、`showStepper`、`minValue`、`maxValue`、`titleUnitRes` 等。Confirm 时调用 `OnInputConfirmedListener.onInputConfirmed(value)`，返回 `true` 则 dismiss。

**理由：** 与已迁移 wrapper 一致；校验逻辑留在 builder 层 lambda，wrapper 只负责 UI 与键盘。

**备选：** 保留 `InputDialogFragment` 仅换 layout — 仍受 DialogFragment 双窗口键盘问题困扰，否决。

### 2. Shared body — `frosted_glass_body_numeric_input.xml`

**决定：** body 含：

- 可选描述 `TextView`（`frosted_glass_numeric_desc`）
- 水平行：减号按钮 + `EditText` + 加号按钮（步进区可通过 `showStepper` 控制 visibility）
- 样式复用 `frosted_glass_body_text_input` 的 EditText 背景/字号/颜色 token（`dialog_edit_bg`、`frosted_glass_text_primary`）

步进逻辑从 `InputDialogFragment` 迁入 wrapper 或 package-private helper（`NumericInputStepHelper`），保持 BigDecimal ±0.1 / ±1 与 clamp 行为。

### 3. 键盘策略 — IME 不压缩背景

**决定：** 三层防护（参考并提炼 `InputDialogFragment.resetHostWindowAfterKeyboard`，但作用于 in-window overlay）：

| 层 | 行为 |
|----|------|
| Host softInputMode | overlay attach 时保存宿主 `softInputMode`，设为 `SOFT_INPUT_ADJUST_NOTHING`；dismiss 时恢复 |
| Card 平移 | 对 overlay 内 card 容器注册 `OnApplyWindowInsetsListener`，读取 `WindowInsetsCompat.Type.ime()` bottom inset，对 card 应用 `translationY = -imeBottom`（或 margin），**不**改变 content root 子 View 的 layout height |
| Dismiss 清理 | `onDismiss`：clearFocus、hideSoftInput、`requestApplyInsets`、必要时 deep `requestLayout`（复用现有 helper 方法） |

实现落点：新增 `FrostedGlassImeCoordinator`（或 package-private 类于 `FrostedGlassOverlayHost` 同包），由 `FrostedGlassNumericInputDialog` 在 show/dismiss 时 attach/detach；numeric wrapper 为首个消费者，后续 WiFi 密码等可复用。

**理由：** in-window overlay 与 Activity 共享同一 window；`ADJUST_NOTHING` 阻止 content root resize，inset 平移仅作用于 overlay card，背景页面保持原尺寸。

**备选：** Dialog 窗口 `ADJUST_PAN` — 已证明无法可靠阻止宿主 resize，否决。

### 4. Builder 迁移 — 去掉 FragmentManager

**决定：**

- `InputDialogBuilder.*Builder()` 返回 `void`，内部直接 `FrostedGlassNumericInputDialog.show(...)`
- `SettingInputDialogBuilder.*Builder()` 同上
- 工程师 fragment / `AdvancedSettingFragment` 删除 `.show(getSupportFragmentManager(), tag)` 链式调用

**理由：** FrostedGlass 非 Fragment；与 `commonlyUsedParameterBuilder` / `materialBuilder` 已迁移模式一致。

### 5. 删除 `InputDialogFragment`

**决定：** 迁移完成并验证后删除 `InputDialogFragment.java`、`DialogInputBinding`、相关 layout/drawable（`dialog_input*`）。不再保留兼容 shim。

**理由：** 无其他 call site；避免双栈维护。

### 6. OpenSpec delta

- 新增 `frosted-glass-numeric-input-dialog` capability spec
- 修改 `frosted-glass-dialog`：移除 numeric 豁免，增加 numeric body 与 IME 要求
- 修改 `engineer-mode-common-params`：扩展 requirement 覆盖数字参数

## Risks / Trade-offs

- **[Risk] overlay card 被 IME 遮挡** → card 平移 + 必要时限制 card 最大高度；真机验证工程师/高级设置各至少一项整数与小数输入
- **[Risk] 多 overlay 栈时 softInputMode 恢复顺序** → `FrostedGlassImeCoordinator` 使用 refcount 或仅 top overlay 持有 mode 覆盖；dismiss 时仅当 refcount=0 恢复
- **[Risk] 宿主 Activity 本身依赖 adjustResize** → 弹窗生命周期内临时 `ADJUST_NOTHING`，关闭后恢复；与 `InputDialogFragment` 现有策略一致
- **[Trade-off] 步进按钮默认显示** → 与 legacy `useNumberInputType()` / `useDecimalNumberInputType()` 均 `setShowController(true)` 行为一致；无步进需求的 builder 可传 `showStepper(false)`（当前无此类 call site）

## Migration Plan

1. 新增 `frosted_glass_body_numeric_input.xml` + `FrostedGlassImeCoordinator` + `FrostedGlassNumericInputDialog`
2. 迁移 `InputDialogBuilder` 全部 numeric builder（保留 text builder 已用 FrostedGlassTextInputDialog）
3. 迁移 `SettingInputDialogBuilder` 全部 builder
4. 更新 fragment call sites（去掉 FragmentManager.show）
5. 删除 `InputDialogFragment` 及 legacy 资源
6. 真机回归：工程师模式（整数/小数/单位标题/描述）、高级设置（有符号整数）、键盘开/关后背景高度正常

## Open Questions

（无 — 键盘策略与 API 形状已对齐既有 FrostedGlass wrapper 模式。）
