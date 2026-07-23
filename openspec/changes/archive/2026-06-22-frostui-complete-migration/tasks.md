# FrostUI 全面迁移任务清单

状态图例：`[ ]` 待做 · `[~]` 进行中 · `[x]` 完成

---

## A. 包路径与结构

- [x] A.1 `FrostButton` / `FrostButtonView` 迁至 `frostui.button`（不再挂在 `card`）
- [x] A.2 评估 `FrostUiClickSoundRegistry` 迁至 `frostui.common`（`card` 包 deprecated 门面已删）
- [x] A.3 `FrostClockAppearance` 从 `FrostGlyphBlurRenderer.kt` 拆到独立文件（`frostui/clock/FrostClockAppearance.kt`）

---

## B. Card（容器）

| 项 | 新版 | Legacy | XML 迁移 | API/样式 |
|----|------|--------|----------|----------|
| 玻璃卡片 | `FrostCard` / `FrostCardView` | `FrostedGlassCard` 已删 | [x] ~120 处 | [x] 见 B.1 |

- [x] **B.1** `FrostCardView` 移除对 `FrostedGlassPanelDrawable` / `FrostedGlassBorderGradientCenter` 的依赖，fill overlay 改用 `border.PanelFillDrawable`（与 `PanelFillPainter` 同源 token）
- [x] **B.2** 确认 `FrostCardAttrs` 与旧 card XML attr 行为一致（blur intensity/tint、transparent 背景、padding）
- [x] **B.3** 删除或内联 `FrostedGlassPanelShell`（light overlay 壳），改由 `frostui.dialog` 提供

---

## C. Button（操作）

| 项 | 新版 | Legacy | XML 迁移 | API/样式 |
|----|------|--------|----------|----------|
| 玻璃按钮 | `FrostButton` / `FrostButtonView` | `FrostedGlassButton` 已删 | [x] ~30 处 | [x] 见 C.1 |

- [x] **C.1** 按压 ripple + alpha 对齐原版
- [x] **C.2** `obtainStyledAttributes` 解析 style（告警/工程师弹窗 primary 等）
- [x] **C.3** `FrostButtonView` 增加 `defStyleAttr`（对齐 Switch/Checkbox）
- [x] **C.4** 视觉回归：按钮尺寸策略已统一（`FrostButtonMeasure` 按 LayoutParams 分支；`minWidth` 不再误触发 `fillMaxWidth`）

---

## D. Control（控件）

| 控件 | 新版 View | Legacy | XML 已换 | 待办 |
|------|-----------|--------|----------|------|
| Switch | `FrostSwitchView` | 无 | [x] 6 layouts | D.1 样式回归 |
| Checkbox | `FrostCheckboxView` | 无 | [x] 6 layouts | D.1 |
| Slider | `FrostSliderView` / `FrostFlankedSliderView` | `ScaledSeekBar` 已删 | [x] 全站 | [x] D.2 视频详情 |
| CapsuleSlider | `FrostCapsuleSliderView` | 无 | [x] 通用设置亮度 | D.1 |
| Segmented | `FrostSegmentedControlView` | 隐藏 RadioButton | [x] 通用设置 | D.1 |
| NumericStepper | `FrostNumericStepperView` | 无 | [x] 1 layout | [x] D.3 SECONDARY variant |

- [x] **D.1** 设置页 Switch/Checkbox/Segment/Capsule 与迁移前截图对比
- [x] **D.2** `activity_process_video_details.xml`：`FlankedSeekBar`/`ScaledSeekBar` → `FrostFlankedSliderView`（内嵌 `FrostSliderView`）
- [x] **D.3** `FrostNumericStepper`：± 用 `FrostButtonVariant.SECONDARY`；删除未使用的 `stepButtonBackgroundRes`
- [x] **D.4** `FrostNumericStepperView` 增加 styleable / `obtainStyledAttributes`（与其他 control 一致）
- [x] **D.5** `FrostSliderView` / `FrostButtonView` 补 theme style attr

---

## E. Dialog（弹窗栈）

| 项 | frostui | Legacy 门面 | 状态 |
|----|---------|-------------|------|
| Overlay | `FrostOverlayHost` | ~~`FrostedGlassOverlayHost`~~ 已删 | [x] E.1 · [x] E.5 |
| Prompt | `FrostPromptDialogController` | ~~`FrostedGlassDialog.prompt()`~~ → **`FrostDialog`** | [x] E.1 · [x] E.5 |
| Backdrop | `FrostBackdropSnapshot` | ~~`FrostedGlassBackdropSnapshot`~~ 已删 | [x] E.2 |
| 专用 dialog | `Frost*Dialog` wrappers | ~~`FrostedGlass*Dialog`~~ | [x] E.7 |

- [x] **E.1** 梳理 `FrostedGlassDialog` → `FrostUiDialogBridge` 调用链，文档化哪些已走 frostui（见 `dialog-call-chain.md`）
- [x] **E.2** 合并 backdrop snapshot 实现，删除 Java 重复类
- [x] **E.3** Date/Time/Number Picker：`NumberPickerUiUtils.applyFrostPickerStyle`（`applyFrostedGlassStyle` 委托已删）
- [x] **E.4** `FrostPopupMenu`（~~`FrostedGlassPopupMenu`~~）保留 app 层

### E.5 命名对齐 `FrostButton`（`FrostedGlass*` → `Frost*`）

对照 Button 迁移：`FrostButton`（Compose）+ `FrostButtonView`（interop），`FrostedGlassButton` 已删。Dialog 栈同理：**frostui 内核已就位**，待统一公开 API 名并删 legacy 门面。

| Legacy | 目标 | 包 |
|--------|------|-----|
| `FrostedGlassDialog` | **`FrostDialog`** | app `ui.component.dialog`（或 `frostui.dialog.interop` 若可去 app 依赖） |
| `FrostedGlassOverlayHost` | **`FrostOverlayHost`**（直接调用，删 wrapper） | frostui |
| `FrostedGlassTone` | **`FrostTone`** | [x] 已删 Java 门面 |
| `FrostedGlassSlotContent` | **`FrostPromptSlotContent`**（已有 Kotlin API） | frostui.dialog |
| `FrostedGlassPromptDialog` | **`FrostPromptDialog`** 或内联 `FrostDialog.prompt()` | app |
| `GlobalDialogUtil.showFrostedGlassPromptDialog` | `showFrostPromptDialog` | [x] 委托已删 |

- [x] **E.5.1** 新增 `FrostDialog`（API 与现 `FrostedGlassDialog` 等价：`prompt()` / `Handle` / lifecycle），内部直调 `FrostOverlayHost` + `FrostPromptDialogController`
- [x] **E.5.2** `FrostedGlassDialog` → `@Deprecated` 薄委托，指向 `FrostDialog`；`FrostedGlassOverlayHost` 已删，直调 `FrostOverlayHost`
- [x] **E.5.3** 迁移 app 调用点（~20 文件）`FrostedGlassDialog` → `FrostDialog`
- [x] **E.5.4** 删除 `FrostedGlassDialog.java`、`FrostedGlassTone.java`（调用点已用 `FrostDialog` / `FrostTone`）
- [x] **E.5.5** 更新 `dialog-call-chain.md`、`frostui-compose-refactor-design.md` 迁移表

### E.6 布局与资源命名（可选、低优先级）

- [x] **E.6.1** `dialog_frosted_glass_*.xml` → `dialog_frost_*.xml`；`frosted_glass_body_*` / `action_*` → `dialog_frost_body_*` / `dialog_frost_action_*`；popup → `frost_popup_menu*`
- [x] **E.6.2** Dialog shell view id / dialog 专用 dimen：`frosted_glass_*` → `frost_dialog_*`（shell slot、prompt dimen、fade、picker 宽度等）；`tv_frosted_glass_*` → `tv_frost_dialog_*`
- [x] **E.6.3** 共享 frostui token（`frosted_glass_*` → `frost_*`：color/dimen/drawable/id/style；`FrostPromptConfirmButton`）

### E.7 专用 dialog wrapper 改名（E.5 之后分批）

| Legacy | 目标 |
|--------|------|
| `FrostedGlassWifiPasswordDialog` | `FrostWifiPasswordDialog` |
| `FrostedGlassNumericInputDialog` | `FrostNumericInputDialog` |
| `FrostedGlassTextInputDialog` | `FrostTextInputDialog` |
| `FrostedGlassStatusDialog` | `FrostStatusDialog` |
| `FrostedGlassPromptDialog` | `FrostPromptDialog` |

- [x] **E.7.1** 逐类 rename + 调用点迁移（`FrostWifiPasswordDialog`、`FrostNumericInputDialog`、`FrostTextInputDialog`、`FrostStatusDialog`、`FrostPromptDialog`；`showFrostPromptDialog`）

---

## F. Token 与绘制（去重）

- [x] **F.1** `FrostedGlassBlurIntensity/Tint/Tone` → 仅保留 `frostui.border.*`；Java 门面已删
- [x] **F.2** `FrostedGlassBorderGradientCenter` → 仅保留 `BorderGradientCenter`；Java 门面已删
- [x] **F.3** `FrostedGlassPanelDrawable` → `PanelFillDrawable` / `PanelBorderDrawable` / `PanelCompositeDrawable` / `PanelShellDrawables`；Java 类已删
- [x] **F.4** `FrostedGlassBlurSupport` 已删（clip 由 frostui blur / View outline 承担）

---

## G. App 层 composite

- [x] **G.1** `FrostQuickActionEntry`（~~`FrostedGlassQuickActionEntry`~~）；ripple 用 `FrostButtonTileRipple`
- [x] **G.2** `FrostRippleClickEntry`（~~`HomeRippleClickEntry`~~）；ripple 用 `FrostButtonTileRipple`
- [x] **G.3** IME 键帽：确认 `ImeKeyPressEffect` → `frostui.button` 按压反馈一致

---

## H. 文档与 Spec

- [x] H.1 更新 `frostui-framework` spec（button 独立包）
- [x] H.2 更新 `frostui-compose-refactor-design.md` 目录树与迁移状态表
- [x] H.3 各 page spec 中 `FrostedGlassButton` 措辞统一为 `FrostButtonView`

### I. Deprecated API 委托清理

- [x] **I.1** 删除 `GlobalDialogUtil.showFrostedGlassPromptDialog`（保留 `showFrostPromptDialog`）
- [x] **I.2** 删除 `NumberPickerUiUtils.applyFrostedGlassStyle`（保留 `applyFrostPickerStyle`）
- [x] **I.3** `AutoDialogQueue.enqueueFrostedGlass` → `enqueueFrostDialog`；`FrostedGlassPresenter` → `FrostDialogPresenter`；`FrostedGlassAutoDialogTask` → `FrostAutoDialogTask`
- [x] **I.4** 删除 `frostui.card.FrostUiClickSoundRegistry` deprecated 门面

---

## J. BlurView 主路径恢复（~~`frostui-restore-blurview-backdrop`~~ 已归档 2026-06-22）

- [x] **J.1** `FrostBlurViewSupport` + `FrostCardView` live `BlurView` 主路径；删除 `FrostStackBlur` / HokoBlur
- [x] **J.2** `FrostBackdropBlurRegistry` → `BlurUtils.blurBitmap`；`FrostBitmapBlur` 薄封装
- [x] **J.3** 首页 stat → `FrostCardView`；`FrostCaptureTarget extends BlurTarget`
- [x] **J.4** 更新 `frostui-framework` / `frostui-home-clock` spec（RenderScript + BlurView）
- [x] **J.5** 模拟器回归（tasks §6 / §7.6）：stat 卡片、prompt、IME、时钟 — 已通过

---

## 建议执行顺序

1. **C.4 + D.1** — 视觉回归，确认已迁移组件无遗漏  
2. **D.3 + D.2** — 小范围组件一致性  
3. **B.1 + F.*** — 去除 frostui→ui 反向依赖（架构债）  
4. **E.5** — `FrostDialog` 命名 + 删 `FrostedGlassDialog` 门面（与 Button 对齐，优先于 E.3 专用 picker）  
5. **E.3、E.7** — 专用 dialog / picker 分批  
6. **A.2、H.2** — 收尾
