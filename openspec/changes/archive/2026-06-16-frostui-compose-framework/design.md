## Context

LWS HMI 的雾化玻璃 UI 当前以 `com.lasercyber.lws.ui.component.dialog` 下 21+ 个 `FrostedGlass*.java` 类及 `frosted_glass_*` XML 资源实现。视觉规范已由 `frosted-glass-components` 与 `frosted-glass-dialog` OpenSpec 约束，但实现与业务 UI 同包，难以独立演进。

`docs/frostui-compose-refactor-design.md` 已定义目标架构：在 **app 模块内**（不新建 Gradle 子模块）建立 `com.lasercyber.lws.frostui` 包，顶层仅 `border` / `card` / `dialog` 三层，使用 Kotlin + Jetpack Compose 重构框架层；`ui` 单向依赖 `frostui`，`frostui` 禁止依赖 `ui`/`ai`。

**本次变更范围（用户确认）**：

- Phase 1～3 全包：含页面卡片迁移与旧 `FrostedGlass*` 清理
- 迁移 `FrostedGlassDialog.prompt()` 高频路径至 frostui 实现
- `frosted_glass_*` token 拆分到独立 `res/values/frostui_*.xml`

## Goals / Non-Goals

**Goals:**

- 建立可独立演进的 `frostui` Compose 框架层（`border` → `card` → `dialog` 依赖链）。
- 在 `:app` 启用 Compose 构建；拆分设计 token 资源文件。
- 实现点击音注入（`FrostUiClickSound` + Registry，`LaserApplication` 委托 `GlobalSoundManager`）。
- `FrostedGlassDialog.prompt()` 由 frostui `dialog` 层实现；`ui` 保留 facade，对外 API 不变。
- 迁移工程师模式 Monitor 卡片、首页 QuickAction 等 Phase 3 场景；提供 `card/interop` 供 Java/XML 嵌入。
- 无引用的旧 `FrostedGlass*` View 类删除；测试迁移至 frostui。

**Non-Goals:**

- 不新建 `:frostui` Gradle 库模块。
- 不在 `frostui` 内复制 `GlobalSoundManager`；告警音/输入反馈音仍由 `ui` 直接调用。
- 不迁移 `GlobalDialogUtil`、`AutoDialogQueue`、`BootSelfCheckGate` 等业务编排至 frostui。
- 不迁移 `WarnDialogUtil` 告警、`ReminderExactDialog`、`WorkStatusDialog` 等特化 shell（除非本变更已触及且安全）。
- 不替换 BlurView；Compose 侧短期用 `AndroidView` 包装。
- 不在 `FrostedGlassDialog` 泛型壳上新增 progress/picker/QR 等内置模式。

## Decisions

### 1. app 内包，三层结构：`border` / `card` / `dialog`

源码根：`app/src/main/kotlin/com/lasercyber/lws/frostui/`。

| 包 | 职责 |
|----|------|
| `border` | `PanelBorderPainter`/`PanelFillPainter`、`BorderGradientCenter`、FrostColors/Dimens/Typography、Tone/BlurTint/BlurIntensity |
| `card` | `FrostCard`、`FrostButton`、`FrostBlur`、`FrostUiClickSound`+Registry、`card/interop/FrostCardView` |
| `dialog` | `FrostPromptDialog`、`FrostOverlayHost`、`FrostOverlayState` |

依赖：`dialog` → `card` → `border`；`border` 不依赖上层。

**备选**：独立 Gradle 模块 `:frostui` — 迁移成本更高，本次不做。

### 2. Compose 在 `:app` 启用，不新建子模块

在 `app/build.gradle.kts` 增加 `buildFeatures.compose`、`composeOptions`（Kotlin 1.9.24 → compose compiler ~1.5.14）、Compose BOM 依赖；版本写入 `gradle/libs.versions.toml`。

**备选**：仅加 Kotlin 不加 Compose — 无法实现框架层 Compose 重构目标。

### 3. 绘制逻辑从 `FrostedGlassPanelDrawable` 迁为 `border` 层 Kotlin 绘制

Sweep/radial/linear 边框渐变、localized capsule 边框、填充渐变抽为纯 Kotlin 函数，供 Compose `Modifier.drawBehind` 使用。视觉以现有 `FrostedGlassPanelDrawableInstrumentedTest` 为回归基准。

**备选**：继续依赖 Java Drawable — 阻碍 Compose 统一、增加跨语言维护成本。

### 4. BlurView 通过 `AndroidView` 包装（`card/FrostBlur`）

`FrostedGlassCard` 的实时 backdrop blur 行为在 Compose 侧用 `AndroidView { BlurView }` 复刻；`SystemSettingUtils`/`AndroidEmulatorUtils` 相关强度逻辑通过 `FrostEnvironment` 接口或参数由 `ui` 注入，避免 `frostui` 依赖 `ui` 工具类。

**备选**：API 31+ 纯 `RenderEffect` — 低版本 fallback 复杂，短期不采用。

### 5. 点击音：依赖倒置，仅点击音

```kotlin
// card/FrostUiClickSound.kt
fun interface FrostUiClickSound { fun playClick() }

// card/FrostUiClickSoundRegistry.kt — register() 公开，playClick() internal
```

`LaserApplication.onCreate()` 在 `GlobalSoundManager.ensureInitialized` 之后注册 lambda 委托 `playClickSound(appContext)`。未注册时 no-op。

**备选**：frostui 内第二套 SoundPool — 禁止（设置不同步、双实例）。

### 6. 资源拆分至 `frostui_*.xml`，仍留 `app/res`

从 `colors.xml`/`dimens.xml`/`styles.xml` 抽出 `frosted_glass_*` 至 `frostui_colors.xml`、`frostui_dimens.xml` 等；`frostui` 代码优先引用拆分后资源。迁移期允许旧 `frosted_glass_*` 别名或 `@color/` 转发，避免一次性改全库引用。

### 7. `FrostedGlassDialog` 作为 `ui` facade，实现委托 frostui

- `FrostedGlassDialog.prompt()` builder API 与 `Handle` 契约不变。
- `show()` 内部调用 `frostui.dialog.FrostPromptDialog` / `FrostOverlayHost`。
- `GlobalDialogUtil.showFrostedGlassPromptDialog` 继续可用。
- `customBodyView` 等仍支持 View 槽位（Compose dialog 内嵌 `AndroidView` 或 `ComposeView`）。

**备选**：对外改名为 `FrostDialog` — **BREAKING**，不采用；保持 `FrostedGlassDialog` 入口。

### 8. Java 互操作：`card/interop`

提供 `FrostCardView`、`FrostButtonView`（`AbstractComposeView`）供 XML 与 Java Fragment 嵌入；Phase 3 页面卡片迁移优先用 interop，降低整页改写成本。

### 9. 渐进迁移与旧代码删除

| Phase | 内容 |
|-------|------|
| 1 | Compose 构建、`border`/`card`、点击音注册、绘制测试 |
| 2 | `dialog` 层、`FrostedGlassDialog.prompt()` 委托、prompt 路径验收 |
| 3 | Monitor 卡片、QuickAction、`FrostCardView` 嵌入；删除无引用 `FrostedGlass*` |

Strangler：旧 View 与 frostui 并存直至调用方切换完毕。

## Risks / Trade-offs

- [视觉漂移] Compose 边框/模糊与 View 版不一致 → instrumented 绘制测试 + emulator `make sync` 每 Phase 对比 prompt/卡片/按钮。
- [Compose Compiler 版本] Kotlin 1.9.24 配对错误导致编译失败 → 锁定 BOM 与 compiler 版本于 `libs.versions.toml`。
- [frostui 反向依赖 ui] 误 import `com.lasercyber.lws.ui.*` → review 门禁；必要时 lint/脚本检查。
- [资源拆分遗漏] 旧引用仍指向已移动 token → 保留转发别名一版，tasks 中列迁移清单。
- [BlurView 生命周期] overlay 栈与 Activity 销毁 → `FrostOverlayHost` 用 `remember` + `DisposableEffect` 对齐现有 `FrostedGlassOverlayHost` 语义。
- [Phase 3 范围大] 80+ 引用点 → 按文件分批迁移，每批可独立验证；未迁移调用方继续用旧 View 直至切换。
- [customBodyView 兼容] 业务布局仍为 XML View → dialog 槽位保留 `AndroidView` 容器，不强制 body 改 Compose。

## Migration Plan

1. **构建与骨架**：Compose 依赖、`frostui` 三包目录、资源拆分文件。
2. **border**：迁移绘制与 token；跑通绘制/模糊测试。
3. **card**：`FrostCard`/`FrostButton`/`FrostBlur`、点击音 Registry、`LaserApplication` 注册。
4. **dialog**：`FrostOverlayHost`/`FrostPromptDialog`；`FrostedGlassDialog` facade 委托。
5. **prompt 验收**：简单 confirm/cancel、scrim dismiss、cancel-only、`Handle` 回调与现网一致。
6. **Phase 3 卡片**：工程师 Monitor、首页 QuickAction 等改用 `FrostCardView` 或 `ComposeView`。
7. **清理**：删除无引用 `FrostedGlass*.java` 与仅被旧实现使用的 layout（保留仍被 customBody 引用的布局）。
8. **回滚**：保留 git 分支；若 prompt 回归失败，facade 可临时切回旧 View 实现（单点开关或 revert）。

## Open Questions

- `FrostedGlassOverlayHost` 当前支持 per-activity 栈叠，而 `frosted-glass-dialog` spec 部分描述为单 overlay；实现 frostui 时以**现有运行时行为**为准，spec delta 仅在确认差异后修正。
- Phase 3 卡片迁移的**精确文件清单**在 apply 阶段按 grep 引用量排序执行，design 不预先锁定每一布局。
- `FrostEnvironment`（模糊强度注入）是否在 Phase 1 即引入，或 Phase 2 dialog 迁移时再加——apply 时若 `FrostBlur` 需要 `ui` 工具类则 Phase 2 前引入最小接口。
