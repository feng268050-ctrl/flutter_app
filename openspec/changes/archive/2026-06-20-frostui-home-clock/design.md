## Context

首页时钟 `home_real_time` 使用 `FrostedGlassTextView`：

- 布局上位于 `BlurTarget` **之外**，以便采样目标内背景。
- 绘制：从 `BlurTarget` 子 View 按屏幕坐标截图 → 缩 1/5 → RenderScript 高斯模糊（半径 25 × 2 遍）→ `getTextPath` + `clipPath` 裁入字形 → 雾面/奶白/描边叠层。
- 刷新：`onAttachedToWindow` 起 `postDelayed(1000)` 循环 `invalidate`；`ensureBlurredBackdrop` 缓存 TTL 亦为 1s。
- 时间：`TimeGlobalManager` 每秒回调；`MainActivity` 每秒 `setText(HH:mm)`，但字符串每分钟才变一次。

`frostui` 已有 `FrostBackdropBlur` / `FrostBackdropSnapshot`（BlurTarget 截图），`FrostUiDialogBridge` 仍注入 RenderScript `BlurUtils`。

## Goals / Non-Goals

**Goals:**

- 用 HokoBlur 替换时钟与 `FrostBackdropBlurRegistry` 路径上的 RenderScript 模糊。
- 将时钟逻辑迁入 `frostui.clock`，`frostui` 不依赖 `com.lasercyber.lws.ui`。
- **按分钟跳变刷新**：同一分钟内不重新采样、不 `invalidate`；分钟变化时 capture + blur + 重绘。
- **方案 B**：`MainActivity` 的 `homeTimeUpdateListener` 仅在 `HH:mm` 变化时调用时钟 API（不在 View 内吞掉每秒 tick）。
- 保留无 `BlurTarget` 时的渐变 fallback；attach / size 变化时立即采样。

**Non-Goals:**

- HokoBlurDrawable / View 背景实时模糊。
- 删除全局 `BlurUtils`（快捷模式遮罩等仍用）。
- 同一分钟内跟踪动效背景（GIF 等）——接受分钟内背景定格。
- 首版 Compose `FrostHomeClock`（可后续加；首版 `FrostHomeClockView`）。

## Decisions

### 1. HokoBlur 静态 API，不用 HokoBlurDrawable

| 参数 | 现实现 | HokoBlur |
|------|--------|----------|
| 缩放 | 1/5 | `sampleFactor(5f)` |
| 算法 | RenderScript 高斯 | `mode(Blur.MODE_GAUSSIAN)` |
| 半径 | 25 × 2 pass | `radius(25)`；偏弱时可双 pass 或调 radius |
| 实现 | RenderScript | `scheme(Blur.SCHEME_NATIVE)`；异常时 fallback `SCHEME_JAVA` |

字形裁剪架构不变；HokoBlurDrawable 已停更且无法做 glyph mask。

### 2. 分钟键驱动刷新（替代 1 Hz 定时器）

删除 `backdropRefreshRunnable` / `BACKDROP_REFRESH_MS` 周期性逻辑。

```kotlin
// 概念：用 hour*60+minute 或 "HHmm" 字符串作为 minuteKey
fun onMinuteChanged(timeMs: Long) {
    updateText(formatHhMm(timeMs))
    requestBackdropCapture()  // async HokoBlur → invalidate once
}
```

| 事件 | 重绘 | 重新采样+模糊 |
|------|------|----------------|
| 同一分钟内 `TimeGlobalManager` tick | 否 | 否 |
| `minuteKey` 变化（含跳时、NTP/手动校时） | 是 | 是 |
| `onAttachedToWindow` / `onSizeChanged` | 是 | 是 |

**不依赖「秒 == 0」**：NTP/`setCustomTime` 可在任意秒触发 listener；以 `HH:mm` 是否变化为准。

`setText` / `updateTime` 在字符串未变时 MUST 短路，避免 `requestLayout` + `invalidate`。

分钟跳变时使用 `HokoBlur.asyncBlur`，完成后主线程 `invalidate` 一次。

### 3. 方案 B：首页 listener 只在分钟变化时更新（已确认）

在 `MainActivity.homeTimeUpdateListener` 中：

1. 格式化为 `HH:mm`。
2. 与 `lastHomeClockMinuteText`（或 `minuteKey`）比较；相同则 **return**。
3. 变化时调用 `binding.homeRealTime.updateTime(currentTime)`（或等价 API），不再每秒裸 `setText`。

可选：不在 `FrostHomeClockView` 内订阅 `TimeGlobalManager`，时间源保持在 Activity 层，职责清晰。

`FrostHomeClockView` 暴露：

```kotlin
fun updateTime(millis: Long)  // 内部 minuteKey 判断 + capture + invalidate
```

### 4. 模块布局

```
frostui/blur/FrostBitmapBlur.kt
frostui/blur/FrostBlurTargetLocator.kt   // 自 FrostedGlassBlurSupport.findLocalBlurTarget 抽出
frostui/clock/FrostGlyphBlurRenderer.kt
frostui/clock/interop/FrostHomeClockView.kt
```

`FrostUiDialogBridge`：`FrostBackdropBlurRegistry` 注册 HokoBlur 实现。

### 5. BlurTarget 查找

`FrostBlurTargetLocator` 在 `frostui` 内实现同级 `BlurTarget` 查找，避免 `frostui` → `ui` 依赖。不迁移 `FrostedGlassBlurSupport` 全量 window session 逻辑（时钟仅需 local target）。

## Risks / Trade-offs

- **[观感]** HokoBlur 与 RenderScript 不一致 → 真机 A/B，调 `radius` / `sampleFactor` / 双 pass。
- **[性能]** 分钟跳变时 capture+blur 偶发卡顿 → `asyncBlur`；59s 内零绘制。
- **[背景动效]** 分钟内模糊背景定格 → 对 `HH:mm` 时钟可接受；后续可加可选低频 refresh。
- **[设备兼容]** Native blur 失败 → fallback `SCHEME_JAVA` 或 `MODE_STACK`。

## Migration Plan

1. 加 HokoBlur + `FrostBitmapBlur`；切换 `FrostBackdropBlurRegistry`。
2. 实现 `FrostHomeClockView` + 分钟刷新策略。
3. 改 `activity_main.xml`、`MainActivity`（方案 B）。
4. 删 `FrostedGlassTextView`；grep 零引用。
5. 真机视觉验收 + emulator sync。

## Open Questions

- HokoBlur 版本：默认 **1.5.5**（实现时核对 Maven 最新）。
- 是否首版同时提供 Compose `FrostHomeClock`：默认否，仅 View interop。
