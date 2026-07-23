## 已确认决策（2026-06-15 需求对齐）

| 项 | 决策 |
|----|------|
| 范围 | 仅 `fragment_common_settings.xml` 5 行；`ScreenDisplayFragment` 无入口，不迁 |
| 分段 API | **保留 `R.id.*` + `check(R.id.xxx)`**，`FrostSegmentedControlView` 对外兼容 `RadioGroup` 式 API |
| 胶囊滑块 | **仅亮度行所需**（百分比 + 尾部图标叠色），不做通用化 variant |
| 视觉 | **以真机 `192.168.0.239:5555` 为参考逐像素对齐**；demo 仅 sync 模拟器 |
| 分段动画 | **短 crossfade**（选中背景/文字过渡），非即时、非 Switch 式 200ms 磁吸 |
| ControlCapsule | 迁移后 **删除** |

## Context

通用设置 `fragment_common_settings.xml`「显示与声音」卡片内，右侧控件统一包在 `ControlCapsule`（`#060720` 圆角胶囊 + 1dp 半透明白边 + 5dp 内边距）中：

| 行 | 现实现 | 视觉 token |
|----|--------|------------|
| 语言 / 单位 / 息屏 / 音效 | `RadioGroup` + `RadioButton` | `radiobutton_background`（选中白底/未选深底）、`radiobutton_text_color`（选中 `#060720`/未选白） |
| 屏幕亮度 | `SeekBar` + `brightness_percent` + `brightness_icon` | `capsule_seekbar_progress`（46dp 高、23dp 圆角、左向 scale 填充）、`seekbar_thumb_v2`（透明无拇指） |

`CommonSettingsFragment` 对亮度行实现了 `updateBrightnessOverlayColors`：根据填充宽度对百分比文字与太阳图标做 `#060720` ↔ 白色渐变（`ArgbEvaluator`）。

已落地：`frostui.control` 中 `FrostSwitch` / `FrostCheckbox` / `FrostSlider`（细轨道 + 圆拇指，用于高级设置）。胶囊控件是**不同变体**，不复用 `FrostSlider` 绘制逻辑。

决策来源：延续 `docs/frostui-control-primitives-design.md` 与 `frostui-control-primitives` change。工作分支：`frost-ui`。

## Goals / Non-Goals

**Goals:**

- 新增 `FrostSegmentedControl`、`FrostCapsuleSlider` Compose 实现 + `Frost*View` interop。
- 视觉逐像素对齐现 `ControlCapsule` + Radio/SeekBar 组合（含亮度叠色）。
- 迁移 `fragment_common_settings.xml` 红框内 5 行；简化 `CommonSettingsFragment` 绑定。
- token 迁入 `frostui_control_*.xml`；点击音经 `FrostUiClickSoundRegistry`。
- 删除 `ControlCapsule.java`（迁移后零引用）。

**Non-Goals:**

- `fragment_screen_display.xml`（旧 mipmap 壳，不同 drawable）。
- 全局替换其他页面 `RadioButton` / `Spinner`。
- 将 `FrostSlider` 与 `FrostCapsuleSlider` 合并为单一组件。
- FrostSelect、Icons 库。

## Decisions

### 1. 两个独立原语，不扩展现有 FrostSlider

| 组件 | 对标 | 关键差异 |
|------|------|----------|
| `FrostSegmentedControl` | `ControlCapsule` + `RadioGroup` | 离散互斥选项；无拖动 |
| `FrostCapsuleSlider` | 亮度 `SeekBar` 行 | 整条胶囊随进度填充；透明拇指；内置叠色 overlay |

`FrostSlider` 保持 12dp 细轨道 + 33dp 圆拇指，仅用于高级设置。

### 2. 胶囊 chrome 内建于 Compose，不单独暴露 FrostControlCapsuleView

`ControlCapsule` 仅为背景 + padding 的 `LinearLayout`。新控件在 Compose 内自绘胶囊边框与内边距，避免 XML 再套一层容器。

`ControlCapsule.java` 迁移完成后删除。

### 3. FrostSegmentedControl API

**Compose:**

```kotlin
FrostSegmentedControl(
    selectedIndex: Int,
    onSelectedIndexChange: (Int) -> Unit,
    options: List<String>,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    appearance: FrostSegmentedAppearance,
)
```

**Interop (`FrostSegmentedControlView`):**

- XML：`app:segmentTexts`（string-array 或 `segmentCount` + 子项 `segmentText`）或运行时 `setOptions(List<String>)`
- `getSelectedIndex()` / `setSelectedIndex(int)`（不触发 listener 时需 `suppressListener` 标志，对齐 `CommonSettingsFragment.suppressCallbacks`）
- **兼容层（已确认）**：保留 `RadioGroup` 式 API — `check(int id)`、`setOnCheckedChangeListener(RadioGroup.OnCheckedChangeListener)`；XML 子项可声明 `android:id` 映射到 segment，Fragment 现有 `R.id.chinese` / `check(R.id.*)` **无需改签名**
- `setOnSegmentSelectedListener((view, index) -> Unit)` 作为可选补充 API

### 4. FrostCapsuleSlider API

**Compose:**

```kotlin
FrostCapsuleSlider(
    progress: Int,
    onProgressChange: (Int, Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    min: Int = 0,
    max: Int = 100,
    valueFormatter: (Int) -> String = { "$it%" },
    trailingIcon: Painter? = null,
    appearance: FrostCapsuleSliderAppearance,
    onStartTracking: (() -> Unit)? = null,
    onStopTracking: (() -> Unit)? = null,
)
```

叠色逻辑移入 Compose：根据 `progress / max` 计算填充右缘，对 leading 文字与 trailing 图标应用与现 `blendOverlayColor` 相同的 `#060720` ↔ `#FFFFFF` 插值。

**Interop:** 对齐 `FrostSliderView` — `setProgress`、`setOnSeekBarChangeListener`、`getMax`；额外 `setTrailingIcon(Drawable)`、`setValueFormatter` 或由 XML `app:valueSuffix="%"` 覆盖。

### 5. 手势与动画

| 控件 | 手势 | 动画 |
|------|------|------|
| Segmented | 点击切换 segment；播放点击音 | **短 crossfade**（背景/文字色过渡，时长待实现时与真机对比微调） |
| CapsuleSlider | 按下即跳位 + 拖动跟手（同 `FrostSlider` 模式：`awaitEachGesture`、无边缘磁吸） | 填充宽度随 progress 连续变化；无额外 snap 动画 |

### 6. 资源 token

| 新 token | 来源 |
|----------|------|
| `frost_capsule_fill` | `#060720` / `control_capsule` solid |
| `frost_capsule_border` | `#40FFFFFF` stroke |
| `frost_capsule_corner_radius` | 30dp（外胶囊）/ 23dp（内滑块轨道） |
| `frost_segment_selected_fill` | white |
| `frost_segment_selected_text` | `#060720` |
| `frost_segment_unselected_text` | white |
| `frost_capsule_slider_height` | 46dp |
| `frost_capsule_inset` | 5dp |

### 7. CommonSettingsFragment 迁移策略

1. 语言/单位/息屏/音效：`binding.languageSetting` 等 `RadioGroup` → `FrostSegmentedControlView`；`check(R.id.*)` → `setSelectedIndex(n)`；listener 改为 index 回调。
2. 亮度：`seekBar` + `brightnessPercent` + `brightnessIcon` 三件套 → 单个 `FrostCapsuleSliderView`；删除 `updateBrightnessOverlayColors` 及 layout change listener。
3. `renderCommonSettings` / `refreshBrightness` / `refreshScreenOffTime` 改用新 API。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 分段控件选项数不一（2/3/4）导致布局挤压 | Compose `Row` + `weight(1f)` 均分，对齐现 `layout_weight` |
| 亮度叠色与真机漂移 | 单元测试 `overlayDarkFraction`；迁移后截图对比 |
| 删除 `ControlCapsule` 漏改引用 | grep `ControlCapsule`；仅 `fragment_common_settings` 使用 |
| 语言切换后 segment 文案需随 locale 更新 | Fragment `renderCommonSettings` 继续 setOptions 或依赖 string resource |

## Migration Plan

```
Phase 0  OpenSpec artifacts + frostui_control_* token 扩展
Phase 1  FrostSegmentedControl Compose + FrostSegmentedControlView + 测试
Phase 2  迁移语言/单位/息屏/音效 4 行 + CommonSettingsFragment 分段绑定
Phase 3  FrostCapsuleSlider Compose + FrostCapsuleSliderView + 叠色测试
Phase 4  迁移亮度行 + 删除 overlay 逻辑 + 删 ControlCapsule.java
Phase 5  emulator 视觉验收 + make sync
```

## Open Questions

- ~~是否在后续 change 中统一 `fragment_screen_display.xml`~~ → **已决：无入口，不迁；可删 dead code**
- ~~分段控件是否需要 XML `android:id` 逐段映射~~ → **已决：保留 `check(R.id.*)` 兼容**
