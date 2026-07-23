## Context

### 当前实现（待替换）

```text
FrostCardView / FrostOverlayHost
  → FrostBackdropCapture (View.draw → Bitmap, 1/3 降采样)
  → FrostStackBlur (CPU IntArray stack blur, 后台单线程)
  → ImageView / Compose Image 静态展示
  → fill + border 叠加
```

`FrostUiDialogBridge` 已将 `FrostBackdropBlurRegistry` 注册为 `BlurUtils.blurBitmap`（RenderScript），但 `FrostCardView` 仍直接调用 `FrostStackBlur`，形成 **注册层 RenderScript、卡片层 CPU** 的分裂。

`HomeStatGlassCard` 仍使用 live `BlurView` + `BlurTarget`（`HomeStatBlurSupport`），是项目内唯一保留的 GPU 实时模糊参考实现。

OpenSpec `frostui-framework` 原文要求 `FrostCard` **MUST show live blurred backdrop via BlurView**；`frostui-home-clock` 曾规划 HokoBlur，与本次「RenderScript + BlurView」方向冲突，需一并修订。

### 目标管线

```text
页面层
  BlurTarget（或 FrostCaptureTarget 标记的背景子树）
       ↑ setupWith(scaleFactor)
  FrostCardView 内 BlurView（GPU 实时模糊 + overlayColor）
       ↑ 可选 freeze: setBlurAutoUpdate(false)
  content + border/fill（Compose chrome）
```

**离线快照**（仅 fallback）：

```text
FrostBackdropCapture → BlurUtils.blurBitmap (RenderScript) → 静态展示
```

**禁止** CPU `FrostStackBlur` 作为主路径或 registry 默认实现。

## Goals / Non-Goals

**Goals:**

- 卡片、对话框 overlay、页面 Frost 卡片默认使用 **live BlurView**，与 `HomeStatGlassCard` 行为一致。
- 所有 Bitmap 离线模糊（fallback、时钟字形裁剪、QuickMode `BlurUtils.showBlurView` 等）统一 **RenderScript `BlurUtils`**。
- 抽取 `frostui/blur/FrostBlurViewSupport.kt`（自 `HomeStatBlurSupport` 提升），供 `FrostCardView`、Compose `AndroidView`、Java interop 共用。
- IME / 自检 dialog 冻结：优先 **停更 BlurView**，而非全屏 CPU 重模糊。
- 删除 `FrostStackBlur` 及依赖它的测试；降低主线程与 `frost-stack-blur` 线程 CPU 峰值。

**Non-Goals:**

- API 31+ 纯 `RenderEffect` 替换 BlurView（低版本 fallback 成本高，本次不做）。
- 恢复对话框 **双层** BlurView（外层 + 内层卡片，见 archive `quick-mode-more-monitor-frosted-glass` 设计 — 仍禁止）。
- 重写 `FrostOverlayHost` 整体 IME 架构（仅替换 blur 后端与冻结语义）。
- 迁移 `QuickModeActivity` / `GeneralOperationsFragment` 的 `BlurUtils.showBlurView`（截图贴图遮罩，非 FrostUI 范围，可后续统一）。

## Decisions

### 1. Live BlurView 作为 FrostCard 默认 blur 层

**选择**: `FrostCardView` 在 `enableBackdropBlur=true` 时，于 `staticBackdropLayer` 位置挂载 `BlurView`（替换当前 `ImageView` + bitmap 矩阵），通过 `FrostBlurViewSupport.setupBlurView` 绑定 sibling `BlurTarget`。

**依据**: `HomeStatBlurSupport` 已验证 `setupWith(blurTarget, scaleFactor=3f)`、`setBlurRadius`、`setOverlayColor`、圆角 `clipToOutline`、triple-invalidate 后 `setBlurAutoUpdate(false)` 冻结。

**Compose**: `FrostSnapshotBlur` 保留给 **已冻结 bitmap** 展示；live 路径新增 `FrostLiveBlur`（`AndroidView` 包装 `BlurView`），或 `FrostCardView` 内直接托管 BlurView、Compose 只画 border/fill。

**备选 — 继续 snapshot+blur**: CPU 低效，用户明确拒绝。

### 2. BlurTarget 解析

**选择**: 复用 `FrostBackdropResolver` / `HomeStatBlurSupport.findSiblingBlurTarget` 逻辑，优先查找同级 `BlurTarget`；`FrostCaptureTarget` 在布局中 **改为继承或包裹 `BlurTarget`**，避免两套标记。

`activity_main.xml` 已有 `<eightbitlab.com.blurview.BlurTarget>` 包裹首页动效层；对话框 overlay 内 light shell 使用 `FrostCaptureTarget` 的页面改为 `BlurTarget` 或 `FrostCaptureTarget extends BlurTarget`。

**备选 — 仅 FrostCaptureTarget + 自研采样**: 当前 snapshot 路径，无 GPU 收益。

### 3. Registry 与 Bitmap 模糊：仅 RenderScript

**选择**: `FrostBackdropBlurRegistry` 默认与 `FrostUiDialogBridge` 注册实现均为 `BlurUtils.blurBitmap`；`frostui` 包 **不** import `BlurUtils`，继续通过 `FrostBackdropBlur` 接口注入。

移除 `FrostBackdropBlurRegistry` 内对 `FrostStackBlur` 的默认 fallback。

**时钟**: `FrostBitmapBlur` 改为薄封装，委托 registry / 注入的 `FrostBackdropBlur`，删除 HokoBlur 调用链。

**备选 — HokoBlur native**: 与「RenderScript」用户要求不一致；且增加第二套 blur 引擎维护成本。

### 4. 删除 FrostStackBlur

**选择**: 删除 `FrostStackBlur.kt` 及引用；instrumented 测试改为验证 RenderScript 输出尺寸与 BlurView 半径映射。

若 RenderScript 在部分设备不可用（极老 API），fallback 为 **不模糊 + PanelDrawable 纯色填充**（与 `HomeStatGlassCard` blur 失败路径一致），**不** 回退 Java 逐像素模糊。

### 5. 对话框 overlay 冻结语义

**选择**:

| 场景 | 行为 |
|------|------|
| 普通 prompt 打开 | live BlurView，`blurAutoUpdate=true` 直至 triple-invalidate 稳定 |
| 需要冻结（overlay 期间页面不动） | `setBlurAutoUpdate(false)`，保留最后一帧 GPU 缓存 |
| BlurView 初始化失败 | 单次 `FrostBackdropCapture` + `BlurUtils` + 静态 `ImageView` |
| IME 抬升 | 卡片 LOCAL 采样由 BlurView 视口自动对齐；避免全屏 bitmap matrix 平移 |

撤销 `docs/frostui-dialog-backdrop-fix-guide.md` §10「禁止恢复 live BlurView」。

**备选 — 全屏 snapshot 冻结为主路径**: 主线程抓图 + CPU/RS 模糊，IME 期间仍易闪烁；与本次目标相反。

### 6. FrostBlurIntensity 半径映射

**选择**: `stackBlurRadiusPx()` 重命名或增加 `blurViewRadiusPx()`，数值对齐 legacy BlurView preset（与 `HomeStatGlassCard` / 原 `FrostedGlassCard` 一致）；`dialogGaussianBlurRadiusPx()` 仅用于 **fallback** RenderScript 快照。

### 7. 模块边界

**选择**: `frostui/blur/FrostBlurViewSupport.kt` 可依赖 `eightbitlab.com.blurview`（已在 `app` 依赖中）；`frostui` 仍不依赖 `com.lasercyber.lws.ui.*`。

`FrostUiDialogBridge` 继续负责 `BlurUtils` 注入与 `FrostCardBlurRegistry` overlay 生命周期。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| BlurView RenderNode 重录开销 | 稳定后 `setBlurAutoUpdate(false)`；scaleFactor=3f 降采样；避免双层 BlurView |
| RenderScript 已弃用 | 与现有 `BlurUtils`、BlurView 内部一致；API 31+ BlurView 走 RenderEffect；长期再评估 |
| Compose + BlurView 生命周期 | `DisposableEffect` 中 `blurView.destroy()` / 释放；对齐 `FrostOverlayHost` overlay 栈 |
| 视觉回归（圆角、叠色） | 对照 `HomeStatGlassCard` 与 `dialog-frost-baseline` tag；instrumented 截图对比 |
| IME 抬升错位 | 保留 LOCAL viewport 语义；BlurView 相对 card 采样，不依赖全屏 matrix |
| HokoBlur 移除影响 | grep 确认无引用后从 `libs.versions.toml` 移除 |

## Migration Plan

### Phase 0 — 设计与规范

- 本 OpenSpec change（proposal / design / specs / tasks）。
- 修订 `docs/frostui-dialog-backdrop-fix-guide.md` 主路径为 BlurView。

### Phase 1 — 共享 BlurView 支持层

1. 新增 `frostui/blur/FrostBlurViewSupport.kt`（自 `HomeStatBlurSupport` 提取）。
2. `HomeStatGlassCard` 改为调用共享支持层（行为不变）。

### Phase 2 — FrostCardView live BlurView

1. `FrostCardView` 挂载 `BlurView`，移除 `FrostStackBlur.blurAsync` 主路径。
2. 保留 bitmap fallback（RenderScript only）。
3. 更新 `FrostCard` Compose 路径（若使用 `FrostSnapshotBlur` 仅用于 frozen/fallback）。

### Phase 3 — Overlay / Registry

1. `FrostOverlayHost` 冻结改为 BlurView stop-update；缩减全屏 snapshot 调用。
2. `FrostBitmapBlur` → RenderScript registry；删除 HokoBlur。
3. `FrostHomeClockView` 改用 registry。

### Phase 4 — 清理

1. 删除 `FrostStackBlur.kt`。
2. 更新/删除相关测试。
3. 移除 `hoko-blur` 依赖（若无引用）。
4. `make sync` emulator 验收：首页 stat 卡片、prompt dialog、自检 dialog、IME 输入 dialog、首页时钟。

### 回滚

- 按 Phase 独立提交；回滚单 Phase 不恢复 `FrostStackBlur` 除非整 change revert。
- `git tag dialog-frost-baseline` 仍作视觉对照，非实现回退目标。

## Open Questions

- `FrostCaptureTarget` 是否直接 `extends BlurTarget`（单类型），还是布局全部改为显式 `BlurTarget`？
- 页面内多张 `FrostCardView` 同时 live blur 时是否默认首张后冻结（与 stat 卡片一致）— 建议 **是**，避免多路 RenderNode 重录。
- RenderScript 在 target SDK 下的 lint 警告是否接受 suppress（与现有 `BlurUtils` 相同策略）。
