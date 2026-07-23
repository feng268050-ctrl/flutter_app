## Why

FrostUI 卡片与对话框背景目前走 `View.draw` 截图 + `FrostStackBlur`（CPU 手写 stack blur）离线管线，主线程抓图、后台逐像素模糊，在 HMI 全屏动效与多 overlay 场景下 CPU 占用高、首帧与重拍延迟明显。项目原本已有成熟的 **BlurView**（GPU RenderNode / API 31+ RenderEffect）与 **RenderScript**（`BlurUtils`）路径，且 `HomeStatGlassCard` 仍在生产使用；应恢复为默认方案，弃用 CPU stack blur 主路径。

## What Changes

- 将 `FrostCardView` / `FrostCard` 的 backdrop blur **改回 live `BlurView`**，对照 sibling `BlurTarget`（或 `FrostCaptureTarget` 兼容包装）实时采样，不再以 `FrostStackBlur` + 静态 `ImageView` 为主路径。
- 将 `FrostBackdropBlurRegistry` 统一注册为 **`BlurUtils.blurBitmap`（RenderScript Gaussian）**；移除对 HokoBlur / `FrostStackBlur` 的对话框快照依赖。
- 首页大时钟 `FrostHomeClockView` 的区域截图模糊改回 **RenderScript**（经 registry 或共享 `FrostBitmapBlur` 封装），与对话框共用 `BlurUtils` 后端；**移除 HokoBlur 依赖**（若全库无其他引用）。
- 删除或降级 `FrostStackBlur`；保留 `FrostBackdropCapture` 仅作 BlurView 不可用时的 **fallback 截图**（仍用 RenderScript 模糊，不用 CPU stack blur）。
- 更新 `docs/frostui-dialog-backdrop-fix-guide.md` 与相关 OpenSpec：撤销「禁止恢复 BlurView / 不扩展 HokoBlur」的临时决策，对齐 `frostui-framework` 原始「live BlurView」要求。
- 对话框 IME 冻结语义恢复为 **`BlurView.setBlurAutoUpdate(false)`**（legacy triple-invalidate 稳定后再冻结），替代全屏 bitmap 冻结为主路径。

## Capabilities

### New Capabilities

- `frostui-home-stat-cards`: 首页 4 张 stat 卡片迁移至 `FrostCardView`，删除 `HomeStatGlassCard`。

### Modified Capabilities

- `frostui-framework`: backdrop blur 实现从 snapshot+stack blur 改回 live BlurView；registry 强制 RenderScript `BlurUtils`，禁止 CPU stack blur 与 HokoBlur 主路径。
- `frostui-home-clock`: 时钟字形裁剪模糊后端从 HokoBlur 改为 RenderScript（与 registry 一致）。
- `frosted-glass-dialog`: 明确 overlay 卡片 MUST 使用 live BlurView（冻结时停更而非 CPU 重算）；快照路径仅 fallback。
- `frostui-framework` (follow-up §7): 首页 stat 卡片 SHALL 使用 `FrostCardView` 而非 legacy `HomeStatGlassCard`。

## Impact

- **代码**: `frostui/blur/`（`FrostStackBlur` 删除）、`frostui/card/interop/FrostCardView.kt`、`frostui/card/FrostBlur.kt`、`frostui/dialog/FrostOverlayHost.kt`、`FrostBackdropSnapshot.kt`、`FrostUiDialogBridge.java`、`FrostHomeClockView.kt`、`HomeStatBlurSupport` 逻辑上提到 `frostui/blur` 共享。
- **依赖**: 保留 `com.github.Dimezis:BlurView`；评估移除 `hoko-blur`。
- **资源**: `activity_main.xml` 中 `BlurTarget` 继续作为采样根；`FrostCaptureTarget` 可保留为 `BlurTarget` 子类或文档别名。
- **测试**: 更新 `FrostBitmapBlurInstrumentedTest`、backdrop 相关测试；instrumented 对比 `HomeStatGlassCard` 与 `FrostCardView` blur 半径/叠色。
- **文档**: `docs/frostui-dialog-backdrop-fix-guide.md`、`docs/frostui-compose-refactor-design.md` 修订。

## Follow-up (tasks §7)

- 首页 4 张 stat 卡片（`box_card1`–`box_card4`）从 legacy `HomeStatGlassCard` 迁移至统一 `FrostCardView`，删除独立 Java 实现；`MainActivity` 冻结/刷新逻辑仅保留 `FrostCardView` 路径。
