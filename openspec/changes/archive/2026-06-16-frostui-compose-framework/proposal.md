## Why

现有雾化玻璃 UI（`FrostedGlass*` View + XML）与 `com.lasercyber.lws.ui` 业务代码同包耦合，难以作为独立设计系统演进；同时项目尚未引入 Jetpack Compose，非对话框场景复用玻璃风格成本高。需要在 **app 模块内** 建立逻辑独立的 `com.lasercyber.lws.frostui` 框架层（`border` / `card` / `dialog`），以 Compose 重构视觉与组件实现，并通过 Strangler 模式完成 `FrostedGlassDialog.prompt()` 及页面卡片的渐进迁移，最终移除已无引用的旧 View 实现。

## What Changes

- 在 `app/src/main/kotlin/com/lasercyber/lws/frostui/` 建立三层框架包：`border`（绘制与 token）、`card`（卡片/按钮/模糊/点击音）、`dialog`（overlay 栈与 prompt 壳）。
- 在 `:app` 启用 Jetpack Compose 构建（BOM、compose compiler，不新建 Gradle 子模块）。
- 将 `frosted_glass_*` 设计 token 拆分到独立 `res/values` 文件（如 `frostui_colors.xml`、`frostui_dimens.xml`），仍位于 `app/src/main/res/`。
- 实现 `FrostUiClickSound` + `FrostUiClickSoundRegistry`；`LaserApplication` 注册并委托现有 `GlobalSoundManager`（仅点击音，不复制 SoundPool）。
- 以 Compose 重写 `border` 绘制逻辑（承接 `FrostedGlassPanelDrawable` 视觉契约）及 `FrostCard` / `FrostButton` / `FrostBlur`。
- 实现 `dialog` 层 `FrostPromptDialog`、`FrostOverlayHost`；`ui` 侧 `FrostedGlassDialog.prompt()` 委托 frostui，保持对外 API 稳定。
- 迁移 `FrostedGlassDialog.prompt()` 高频路径至 frostui 实现；Phase 3 迁移工程师模式 Monitor 卡片、首页 QuickAction 等内嵌卡片场景。
- 提供 `card/interop`（`FrostCardView` 等）供 Java/XML 页面嵌入 Compose 组件。
- 旧 `FrostedGlass*` View 类在无引用后删除；业务编排（`GlobalDialogUtil`、`AutoDialogQueue`、`BootSelfCheckGate` 等）留在 `ui`。
- 迁移/新增 `border` 绘制与模糊强度测试；emulator 视觉回归。

## Capabilities

### New Capabilities

- `frostui-framework`: 定义 app 内 `com.lasercyber.lws.frostui` 框架层的包结构、依赖边界、Compose 构建、点击音注入、资源拆分及与 `ui`/`ai` 的集成契约。

### Modified Capabilities

- `frosted-glass-components`: 实现载体从 View（`FrostedGlassCard`/`FrostedGlassButton`）迁移为 frostui Compose 组件（`FrostCard`/`FrostButton`）；视觉与 `borderGradientCenter` 行为契约不变；保留 interop 供过渡期 XML 使用。
- `frosted-glass-dialog`: `FrostedGlassDialog.prompt()` 及 overlay 栈由 frostui `dialog` 层实现；对外入口 API 与槽位语义不变；`GlobalDialogUtil.showFrostedGlassPromptDialog` 继续可用。

## Impact

- **源码**: 新增 `app/src/main/kotlin/com/lasercyber/lws/frostui/{border,card,dialog}/`；逐步删除 `ui/component/dialog/FrostedGlass*.java`（无引用后）。
- **构建**: `app/build.gradle.kts`、`gradle/libs.versions.toml` 增加 Compose 依赖与 compiler 配置。
- **资源**: `app/src/main/res/values/frostui_*.xml` 从现有 `frosted_glass_*` token 拆分；调用方逐步改引用。
- **应用入口**: `LaserApplication` 注册 `FrostUiClickSoundRegistry`。
- **调用方**: `FrostedGlassDialog`、`GlobalDialogUtil`、工程师模式/Monitor/首页等卡片场景；旧 View 引用随 Phase 切换。
- **测试**: `FrostedGlassPanelDrawableInstrumentedTest`、`FrostedGlassBlurIntensityTest` 迁移或对接 frostui。
- **依赖**: 新增 Compose BOM；保留 BlurView（Compose 侧 `AndroidView` 包装）。
- **非影响**: 不新建 `:frostui` Gradle 模块；`ai` 包通常不依赖 frostui；告警音/输入反馈音仍由 `ui` 直接调 `GlobalSoundManager`。
