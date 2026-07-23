# FrostUI 对话框背景模糊修复指导

> **2026-06-22 方向更新**：见已归档 OpenSpec change [`frostui-restore-blurview-backdrop`](../openspec/changes/archive/2026-06-22-frostui-restore-blurview-backdrop/design.md)。**已实现**：主路径为 **live BlurView + RenderScript fallback**；CPU `FrostStackBlur` 与 HokoBlur 已移除。下文 capture/IME 时序分析仍可参考；§2 能力表已按当前代码更新。

本文档记录 FrostUI 对话框背景模糊的架构与修复要点。目标是解决：

1. 对话框圆角模糊填充不完整；
2. 非 IME 对话框存在透视背景拖拽、漂移；
3. IME 唤醒期间模糊出现不流畅、存在短暂视觉停留。

本文档以 **2026-06-22 当前工作区代码**为依据。`FrostCardView` 主路径已使用 live `BlurView`（`FrostBlurViewSupport`）；离线 fallback 走 `FrostBackdropBlurRegistry`（RenderScript）。

相关资料：

- `docs/frostui-compose-refactor-design.md`
- `docs/ime-compose-refactor-design.md`
- `openspec/changes/ime-compose-refactor/`
- `openspec/specs/frosted-glass-dialog/spec.md`

已知回滚基线：

```bash
git tag -l 'dialog-frost-baseline'
git show dialog-frost-baseline --stat
```

`dialog-frost-baseline` 指向 commit `53182078`。该标签只能作为历史对照，不代表当前目标实现。

---

## 1. 修复边界

本次继续使用：

```text
BlurTarget（页面背景）
    → live BlurView（GPU 实时模糊 + overlayColor）
    → 稳定后 setBlurAutoUpdate(false) 冻结
    → frostPanelFill / border 叠加

fallback only:
View.draw 截图 → BlurUtils RenderScript → 静态 ImageView
```

本次不做：

- 不恢复双层 BlurView（外层 + 内层卡片）；
- 不使用 CPU FrostStackBlur；
- 不要求先完成整个 `ime-compose-refactor`；
- 不实现每帧实时跟踪背景动画（冻结后停更 BlurView）。

IME 包重构与对话框视觉修复需要保持解耦：先在现有 coordinator 路径上修好 capture 时序，再由 `ImeRegistry` 平移到新架构。

---

## 2. 当前代码审计

### 2.1 已经具备的能力

当前工作区已有以下基础能力，可以继续使用：

| 能力 | 位置 | 状态 |
|------|------|------|
| LOCAL / FULLSCREEN 显示模式 | `FrostBackdropDisplayMode` | 已存在 |
| 卡片区域截图 | `FrostBackdropCapture.captureRegion` | 已存在 |
| Anchor capture | `assignFrozenBackdropForAnchor` | 已存在 |
| Live BlurView 设置 | `FrostBlurViewSupport.setupBlurView` | 已存在 |
| RenderScript 离线模糊 | `FrostBackdropBlurRegistry` / `FrostBitmapBlur` | 已存在 |
| 异步结果失效控制 | `backdropCaptureGeneration` | 已存在 |
| Anchor 元数据 | `FrozenDialogAnchor` | 已存在 |
| Compose bitmap 展示 | `FrostSnapshotBlur` | 已存在（frozen/fallback） |

### 2.2 当前断链

以下问题仍然存在：

| 断链 | 当前行为 | 后果 |
|------|----------|------|
| 非 IME 首帧 | `attachOverlaySync` 在 overlay attach 前同步抓 FULLSCREEN | 主线程开销；无法获得最终 card anchor |
| 默认重试 | `tryAssignFrozenBackdrop()` 仍只抓 FULLSCREEN | 普通 prompt 没有进入 LOCAL 主路径 |
| 动态尺寸通知 | `notifyDialogCardBoundsChanged()` 无有效调用方 | 已写的异步 anchor 重拍能力未闭环 |
| 重拍显示策略 | `clearDisplayedBackdropOnOverlays()` 先清空旧图 | 产生短暂空白或 fill 突变 |
| 开机自检 | manual defer 未接入，footer 后也没有最终 capture | 动态增高期间仍可能错位，最终状态无明确采样点 |
| IME wrapper | 三个输入 dialog 移除了 `deferFrozenBackdropUntilIme(true)` | 暂时减少空窗，但键盘抬升后透视区域会错位 |
| IME refresh | `refreshFrozenBackdropAfterIme()` 只做 matrix apply | deferred 时没有 bitmap，无法完成首次 capture |
| 圆角 fill | prompt 的 `frostedGlassStackPanelFill=false` | 圆角完全依赖 blur bitmap，容易露底 |
| 圆角 bleed | `1.06f` 且从 TopStart 放大 | 右下补偿多、左上补偿少，视觉不对称 |

因此，修复不能继续在 FULLSCREEN matrix 上打补丁，必须先统一 capture 生命周期。

---

## 3. 目标状态

### 3.1 Capture policy

对话框需要显式区分三种采样策略，避免继续叠加布尔条件：

```kotlin
enum class FrostBackdropCapturePolicy {
    AUTO_AFTER_LAYOUT,
    AFTER_IME_STABLE,
    MANUAL,
}
```

| Policy | 使用场景 | 首次 capture 时机 |
|--------|----------|-------------------|
| `AUTO_AFTER_LAYOUT` | 普通确认框、WiFi 提示 | card 首次有效 layout 后 |
| `AFTER_IME_STABLE` | 数字、文本、WiFi 密码输入 | IME 可见且 card translation 已应用后 |
| `MANUAL` | 开机自检等动态内容 | 业务明确通知最终布局完成后 |

如果本轮不希望引入 enum，至少应增加独立的
`deferFrozenBackdropUntilManualCapture` 配置，并只由实际开机自检 dialog 设置。

禁止直接使用 `BootSelfCheckGate.isActive()` 推导 `MANUAL`。该 gate 表示系统处于自检阶段，不等同于“当前显示的一定是自检弹窗”，否则其他弹窗可能永久等待手动 capture。

### 3.2 Display state

卡片视觉状态应为：

```text
PLACEHOLDER
    ↓ 首次 capture
CAPTURING_INITIAL
    ↓ blur 完成
READY
    ↓ bounds / IME 变化
CAPTURING_REPLACEMENT ──失败──→ READY（保留旧图）
    ↓ 成功
READY（替换为新图）
```

必须遵守：

- `PLACEHOLDER` 始终显示 panel fill，不能透明；
- replacement capture 期间保留旧 bitmap；
- 新 bitmap 到达后再替换；
- 旧异步结果通过 generation token 丢弃；
- 只有 overlay dismiss 时才完全清空 backdrop。

### 3.3 Capture frame

建议将 bitmap、显示模式和几何信息作为一个整体保存：

```kotlin
data class FrostBackdropFrame(
    val bitmap: Bitmap,
    val mode: FrostBackdropDisplayMode,
    val anchor: FrozenDialogAnchor?,
    val scaleFactor: Float,
    val overscanPx: Int,
    val generation: Int,
)
```

不要继续只通过 bitmap 尺寸推断它是 LOCAL 还是 FULLSCREEN。显式元数据可以避免尺寸取整、overscan 或卡片 resize 后误判。

---

## 4. 统一渲染原则

### 4.1 LOCAL 是默认路径

普通 prompt、IME prompt、开机自检最终状态全部使用：

```text
最终 card bounds
    → LOCAL capture
    → async blur
    → LOCAL display
```

LOCAL bitmap 不需要跟随 card 屏幕位置调整 matrix。卡片位置变化时，应重新采样，而不是平移旧背景。

### 4.2 FULLSCREEN 仅为 fallback

只有在 card 多次 layout 后仍无有效尺寸时，才允许使用 FULLSCREEN：

- fallback 必须有明确超时或重试上限；
- 保存 capture 时的 card anchor；
- 应用时裁剪一次并锁定；
- 后续 `onLayout` 不得持续修改 FULLSCREEN offset；
- card bounds 稳定后应允许升级为 LOCAL frame。

### 4.3 Capture 与 blur 分线程

```text
主线程：读取 bounds + View.draw
工作线程：FrostStackBlur
主线程：校验 generation + apply/crossfade
```

禁止在 `attachOverlay()` 或 IME inset 回调中同步执行完整 `captureAndBlur()`。

### 4.4 重拍不清空旧图

当前 `clearDisplayedBackdropOnOverlays()` 不应作为正常重拍步骤。

正确顺序：

```text
保留 oldFrame
    → capture new snapshot
    → async blur
    → generation 校验
    → newFrame fade in
    → 释放 oldFrame
```

首次 capture 没有 oldFrame 时，底层 panel fill 充当 placeholder。

---

## 5. 分阶段实施计划

### Phase 0：收口状态与日志

目标：先建立可验证的统一入口，不改变最终视觉。

#### 改动

1. 为 session 明确保存 policy、capture state、frame mode、anchor 和 generation。
2. 收敛首次 capture、bounds recapture、IME capture、manual capture 到同一个 request API，例如：

   ```kotlin
   requestBackdropCapture(activity, reason, preferredMode = LOCAL)
   ```

3. 每个 Activity 同时只允许一个 blur job；新请求递增 generation，旧结果自然失效。
4. 增加统一日志：

   ```text
   request reason=initial policy=AUTO_AFTER_LAYOUT generation=3
   capture mode=LOCAL bounds=... overscan=...
   blurComplete generation=3 elapsedMs=...
   dropStale generation=2 current=3
   apply mode=LOCAL generation=3
   ```

#### 关键文件

- `FrostOverlayHost.kt`
- `FrostBackdropSnapshot.kt`
- `FrostCardView.kt`

#### 完成条件

- capture 请求只有一个入口；
- 日志能区分 initial、bounds、IME、manual；
- 无同步 blur 新增。

---

### Phase 1：修复普通非 IME 对话框

目标：普通 prompt 打开后透视固定，不随 layout 漂移。

#### 改动

1. 删除 `attachOverlaySync` 的同步 FULLSCREEN capture。
2. overlay attach 后等待 card 首次有效 layout。
3. 首次 capture 优先 LOCAL，并异步 blur。
4. 首帧等待期间显示 panel fill。
5. `tryAssignFrozenBackdrop()` 改为：

   ```text
   LOCAL available → request LOCAL
   LOCAL unavailable but still within retry window → wait
   timeout → FULLSCREEN fallback
   ```

6. FULLSCREEN fallback 应裁成 card viewport 后锁定，不在每次 `onLayout` 平移。

#### 不应做

- 不在 attach 前抓全屏；
- 不因为 capture 尚未完成而隐藏整个 chrome；
- 不在普通固定尺寸 prompt 上持续 recapture。

#### 验收

- WiFi 初始化提示打开后背景位置稳定；
- 通用 confirm/cancel dialog 无纵向拖拽；
- 打开过程允许短暂 panel fill，但不允许透明卡片；
- `Choreographer` 中不出现同步 Stack Blur 长任务。

---

### Phase 2：修复动态非 IME 对话框

目标：开机自检逐行增高时不拖拽，最终背景与最终卡片一致。

#### 推荐策略：最终布局单次 capture

开机自检使用 `MANUAL` policy：

```text
显示 dialog
    → panel fill placeholder
    → 逐行追加检查结果
    → footer visible
    → 等待下一次有效 layout
    → 单次 LOCAL capture
    → fade in
```

#### 改动

1. 由 `BootSelfCheckDialog` 显式设置 manual policy。
2. `FrostPromptDialogController` 将该 policy 传给 `FrostOverlayHost`。
3. `showFooterSync()` 在 footer 可见并完成 layout 后调用
   `captureFrozenBackdropAtAnchor()` 或统一 request API。
4. 如果 capture 失败，保留 panel fill，并进行有限次数重试。
5. 删除自检场景的“先抓小卡片，再 footer 后抓大卡片”路径。

#### 其他动态 prompt

若有必须在展示期间持续改变尺寸的 dialog：

- bounds 变化后 debounce 100–150ms；
- debounce 到期后重新 LOCAL capture；
- blur 期间保留旧 frame；
- 仅尺寸或位置实际变化时请求重拍。

#### 验收

- 自检逐行追加时没有背景纹理被向上拖动；
- footer 出现后只发生一次可感知的 blur fade；
- 首页动画仍可播放，允许 card 内冻结帧与 card 外动画存在轻微静动态差异；
- 其他自检阶段弹窗不会因 gate 状态进入 manual policy。

---

### Phase 3：修复 IME 对话框

目标：键盘弹出期间没有透明空窗、硬切和错误透视。

#### 临时实现原则

本 Phase 不等待 `ime-compose-refactor` 完成。先在现有
`FrostedGlassImeCoordinator` 中接通行为，后续再平移到 `ImeController`。

#### 改动

1. 恢复输入 dialog 的 `AFTER_IME_STABLE` 语义：

   - `FrostedGlassNumericInputDialog`
   - `FrostedGlassTextInputDialog`
   - `FrostedGlassWifiPasswordDialog`

2. defer 期间只禁止错误 backdrop，不禁止 panel fill。
3. IME inset 首次达到阈值后：

   ```text
   计算 translationY
       → 应用 card translation
       → 下一帧读取最终 screen bounds
       → request LOCAL async capture
   ```

4. `refreshFrozenBackdropAfterIme()` 必须发起首次 LOCAL capture，不能只做 matrix apply。
5. IME 动画期间若 translation 再变化：

   - 递增 generation；
   - debounce 至位置稳定；
   - 丢弃旧 blur 结果；
   - 对最终 bounds 重拍。

6. 新 frame 使用 80–120ms fade-in。若已有旧 frame，执行双层 crossfade；没有旧 frame 时从 panel fill 过渡。
7. 保留现有 `softInputMode` 保存、`ADJUST_NOTHING`、dismiss 后恢复逻辑。

#### 避免

- 不通过移除 defer 来掩盖空窗；
- 不以 double `post` + 固定 120ms retry 作为主时序；
- 不在每个 global layout 回调同步截图和模糊；
- 不对已经失效的 IME bounds 应用旧结果。

#### 验收

- 数字、文本、WiFi 密码 dialog 打开后始终有可见 frost fill；
- 键盘抬升过程中无透明白板；
- 模糊出现没有明显硬切；
- 键盘稳定后卡片内透视与其背后区域一致；
- 快速打开、关闭、再次打开不会应用上一轮 bitmap；
- dismiss 后宿主页面尺寸和 `softInputMode` 正常恢复。

---

### Phase 4：修复圆角填充

目标：在 capture 生命周期稳定后修复四角缺口，避免用错误 bitmap 对齐结果调视觉参数。

#### 第一步：恢复 prompt fill

仅修改 `dialog_frosted_glass_prompt.xml`：

```xml
app:frostedGlassStackPanelFill="true"
```

该修改只用于 DARK prompt shell。页面 stat card、工程师页面卡片继续按各自配置使用 `false`。

#### 第二步：LOCAL capture overscan

LOCAL capture 增加 8–12px 原始像素 overscan。显示时必须采用以下任一种明确方式：

- bitmap 居中裁剪到 card；
- 按 overscan 元数据执行负向 offset；
- 使用等价的 center-crop。

禁止“扩大 bitmap 后仍按 TopStart 对齐”，否则会形成方向性偏差。

#### 第三步：bleed 微调

先验证 fill + overscan，再决定是否将 `BLUR_CORNER_BLEED_SCALE` 从 `1.06f`
提高到约 `1.08f–1.10f`。

bleed 必须围绕中心放大，而不是以 `(0, 0)` 为 transform origin。

#### 最后手段：corner seal

只有 fill、overscan、center bleed 后仍有设备相关细缝时，才增加 corner seal。
corner seal 应使用与当前 tint 接近的低 alpha 填充，不能覆盖边框高光。

#### 验收

- 四角没有透明缝、亮边或未模糊三角区；
- 边框仍位于最上层且连续；
- DARK prompt 浓度没有明显过重；
- 页面内 `FrostCardView` 视觉不受影响。

---

### Phase 5：清理与架构迁移

前三类问题稳定后再进行：

1. 将 IME capture 回调迁移到 `ImeRegistry`；
2. 将 policy 接入 `FrostPromptConfig.imeConfig`；
3. 删除旧的 matrix-only、未调用 recapture API；
4. 删除通过 bitmap 尺寸猜测 display mode 的逻辑；
5. 更新：

   - `openspec/changes/ime-compose-refactor/tasks.md`
   - `openspec/specs/frosted-glass-dialog/spec.md`

不要把 visual bug fix 与完整 IME Compose 组件迁移放在同一个不可回滚提交中。

---

## 6. 场景决策表

| 场景 | Policy | 初始显示 | Capture | 更新策略 |
|------|--------|----------|---------|----------|
| 普通非 IME prompt | AUTO_AFTER_LAYOUT | panel fill | LOCAL async | 固定尺寸不重拍 |
| 普通 prompt fallback | AUTO_AFTER_LAYOUT | panel fill | FULLSCREEN async | 裁剪并锁定，后续升级 LOCAL |
| 开机自检 | MANUAL | panel fill | footer layout 后 LOCAL async | 默认只拍一次 |
| 其他动态 prompt | AUTO_AFTER_LAYOUT | panel fill / old frame | LOCAL async | bounds debounce 后重拍 |
| IME 输入 | AFTER_IME_STABLE | panel fill | translation 稳定后 LOCAL async | IME bounds debounce |
| 页面内 frost card | 页面自身策略 | 现有行为 | LOCAL | 不在本文范围 |

---

## 7. 文件级改动清单

| 文件 | 计划 |
|------|------|
| `frostui/dialog/FrostOverlayHost.kt` | 统一 request API、policy/state、LOCAL 默认、FULLSCREEN fallback、generation |
| `frostui/dialog/FrostBackdropSnapshot.kt` | UI capture + worker blur API；返回明确 frame 元数据 |
| `frostui/card/interop/FrostCardView.kt` | placeholder、保留 old frame、crossfade、禁止 layout matrix 漂移 |
| `frostui/card/FrostBlur.kt` | center alignment、overscan 显示、bitmap alpha |
| `frostui/dialog/FrostPromptConfig.kt` | capture policy 或显式 manual defer |
| `frostui/dialog/FrostPromptDialogController.kt` | 将 policy 正确传入 host |
| `ui/common/boot/BootSelfCheckDialog.java` | footer layout 后发起 manual LOCAL capture |
| `ui/component/dialog/FrostedGlassImeCoordinator.java` | IME 稳定后发起 LOCAL capture |
| 三个 `FrostedGlass*InputDialog` | 恢复 AFTER_IME_STABLE 语义 |
| `res/layout/dialog_frosted_glass_prompt.xml` | prompt-only stack fill |

---

## 8. 测试与性能验证

### 8.1 自动测试

至少补充：

- LOCAL / FULLSCREEN frame 元数据测试；
- overscan capture 尺寸与裁剪坐标测试；
- stale generation 结果不应用；
- bounds debounce 合并多个请求；
- manual policy 不会自动 capture；
- IME policy 只在 translation 应用后 capture。

建议命令：

```bash
./gradlew :app:testDebugUnitTest
```

### 8.2 手动回归矩阵

| 场景 | 检查项 |
|------|--------|
| WiFi 初始化提示 | 首帧、圆角、背景稳定 |
| 普通确认/取消 | 无拖拽、无透明空窗 |
| 开机自检逐行执行 | 增高期间稳定、footer 后单次 fade |
| 工程师数字输入 | IME 抬升、± 操作、dismiss 恢复 |
| 文本输入 | 快速输入、快速关闭、再次打开 |
| WiFi 密码 | IME Connect、最终透视对齐 |
| 首页动画背景 | card 内冻结帧不发生位置滑动 |
| overlay 连续切换 | bitmap 不串场、generation 正确 |

### 8.3 性能约束

- `FrostStackBlur` 不在主线程执行；
- attach 不同步执行完整全窗 capture + blur；
- 同一 Activity 最多一个有效 blur job；
- bounds 高频变化必须 debounce；
- bitmap 替换前不主动 recycle Compose 仍可能绘制的实例；
- 使用 trace 或日志记录 capture、blur、apply 耗时。

同步验证：

```bash
ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync
```

真机验收应至少覆盖实际 HMI 分辨率和软键盘。

---

## 9. 回滚与提交策略

建议拆分提交：

```text
1. refactor(frost): unify dialog backdrop capture state
2. fix(frost): use local backdrop for non-ime prompts
3. fix(frost): finalize boot self-check backdrop capture
4. fix(frost): smooth ime deferred backdrop transition
5. fix(frost): seal prompt rounded backdrop corners
```

每个提交都应能独立构建。若某阶段视觉验收失败，只回滚该阶段，不回滚整个 FrostUI Compose 迁移。

---

## 10. 禁止事项

| 做法 | 原因 |
|------|------|
| 恢复 live BlurView | 已恢复为默认路径（见 `openspec/changes/archive/2026-06-22-frostui-restore-blurview-backdrop`） |
| 使用 CPU FrostStackBlur | 低效，已删除 |
| attach 前同步全窗 blur | 阻塞主线程，且没有最终 card bounds |
| 重拍前清空旧 bitmap | 制造空窗和视觉闪烁 |
| 通过移除 IME defer 解决卡顿 | 会恢复键盘抬升后的透视错位 |
| 用 `BootSelfCheckGate` 直接决定 manual capture | gate 范围大于实际自检 dialog |
| 每次 `onLayout` 平移 FULLSCREEN matrix | 动态居中卡片必然产生拖拽感 |
| 只增加 bleed | 无法解决错误 capture 和 matrix 生命周期 |
| 一次提交视觉修复与完整 IME 重构 | 验收和回滚边界不可控 |

---

## 11. 最终验收标准

修复完成必须同时满足：

- 普通非 IME prompt 使用 LOCAL 为主路径；
- 开机自检动态增高期间无透视拖拽；
- IME dialog 从打开到键盘稳定全程无透明空窗；
- 新 blur 使用异步计算并以 fade/crossfade 应用；
- 重拍期间保留 old frame 或 panel fill；
- DARK prompt 四角填充完整；
- FULLSCREEN 只作为有限 fallback；
- overlay dismiss 后 bitmap、job、IME window 状态均正确释放；
- 页面内 FrostCard 和首页时钟没有视觉回归。

---

*文档版本：2026-06-18。状态：重新规划，待按 Phase 0–5 实施和验收。*
