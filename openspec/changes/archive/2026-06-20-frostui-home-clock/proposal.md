## Why

首页大时钟仍由 `FrostedGlassTextView`（Java）实现，背景模糊依赖已弃用的 RenderScript（`BlurUtils`），且与 FrostUI 设计系统脱节。当前实现每秒触发 `invalidate` 与潜在背景重采样，但显示格式为 `HH:mm`，同一分钟内 59 秒均为无效工作。在 `frost-ui` 分支将时钟迁入 `frostui`、改用 HokoBlur，并改为按分钟跳变刷新，可统一模糊引擎并显著降低 CPU/GPU 开销。

## What Changes

- 引入 **HokoBlur**（`io.github.hokofly:hoko-blur`）静态 Bitmap 模糊 API；**不使用** HokoBlurDrawable。
- 新增 `frostui/blur/FrostBitmapBlur`、`frostui/blur/FrostBlurTargetLocator`、`frostui/clock/`（`FrostGlyphBlurRenderer`、`FrostHomeClockView`）。
- 将 `FrostBackdropBlurRegistry` 注册实现从 RenderScript `BlurUtils` 切换为 HokoBlur（对话框快照与时钟共用）。
- 迁移 `activity_main.xml` 中 `home_real_time` → `FrostHomeClockView`；`MainActivity` 改为 **方案 B**：`TimeGlobalManager` listener 仅在 `HH:mm` 变化时更新时钟。
- **刷新策略**：删除每秒 `postDelayed`；背景采样+模糊与重绘仅在分钟跳变（或 attach/resize/校时导致 `HH:mm` 变）时执行；其余 59 秒复用缓存。
- 删除 `FrostedGlassTextView.java`（迁移验收后）。
- 本 change **不删除** `BlurUtils`（快捷模式等仍使用）。

## Capabilities

### New Capabilities

- `frostui-home-clock`: 定义首页 Frost 时钟的 Compose/View interop、HokoBlur 字形裁剪绘制、分钟级刷新策略，以及 `MainActivity` 绑定契约。

### Modified Capabilities

- `frostui-framework`: `frostui` 包扩展 `blur` 与 `clock` 子模块；`FrostBackdropBlurRegistry` 模糊实现切换为 HokoBlur。

## Impact

- **依赖**：`gradle/libs.versions.toml`、`app/build.gradle.kts` 新增 HokoBlur。
- **源码**：`app/src/main/kotlin/com/lasercyber/lws/frostui/{blur,clock}/`；`FrostUiDialogBridge.java`；`MainActivity.java`；`activity_main.xml`。
- **删除**：`FrostedGlassTextView.java`。
- **保留**：`BlurUtils.java`（非 frost 路径）、`FrostedGlassBlurSupport`（对话框 live blur）。
- **测试**：`FrostBitmapBlur` 参数单元测试；真机 `192.168.0.239:5555` 视觉对比；emulator `make sync` 验证分钟跳变与校时。
