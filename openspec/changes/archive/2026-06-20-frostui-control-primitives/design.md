## Context

LWS HMI 的 Switch（`ui.component.Switch`）、Checkbox（`ui.component.Checkbox`）与高级设置线性滑块（`ScaledSlider`）为 Java 自绘 View，token 分散在 `attrs.xml` / `styles.xml`。FrostUI 已在 `frostui.{border,card,dialog}` 落地 Card/Button/Dialog 的 Compose + `interop` 模式。

决策来源：`docs/frostui-control-primitives-design.md`（§3、§10）。工作分支：`frost-ui`；本阶段不合 `dev`。

## Goals / Non-Goals

**Goals:**

- 新增 `frostui.control`：`FrostSwitch`、`FrostCheckbox`、`FrostSlider`（LINEAR）及 `Frost*View` interop。
- 迁移全部 Switch/Checkbox layout 与 `fragment_advanced_setting.xml` 内 `ScaledSlider`。
- 删除 `Switch.java`、`Checkbox.java`、`ScaledSlider.java`；**保留** `ScaledSeekBar.java`（`FlankedSeekBar` 依赖）。
- token 迁入 `frostui_control_*.xml`；视觉 **逐像素** 对齐（200ms 动画）。
- 可点击控件经 `FrostUiClickSoundRegistry` 播放点击音。

**Non-Goals:**

- FrostSelect、FlankedSeekBar、GearPick/WheelView、Icons/Material Icons。
- 替换 `RadioButton`、工程师 `FrostedGlassPopupMenu` 主题。
- 新建 Gradle 子模块；`frostui` 依赖 `ui`/`ai`。

## Decisions

### 1. 第四层包 `frostui.control`

| 选用 | `com.lasercyber.lws.frostui.control` + `control/interop` |
| 备选 | 并入 `frostui.card` — 拒绝，避免 card 语义膨胀 |

依赖：`control → border`；`ui` → `control`。

### 2. Compose 为唯一视觉源 + AbstractComposeView interop

对齐 `FrostButtonView`：`FrostSwitchView` / `FrostCheckboxView` / `FrostSliderView` 用 `mutableStateOf` 驱动 `Content()`。

- Switch/Checkbox：`Canvas` + `animateFloatAsState`（200ms）
- Slider：Compose `Slider` 或自绘轨道，颜色/拇指对齐 `scaled_seekbar_*` drawable；刻度行复刻 `ScaledSlider` 布局逻辑

### 3. 破坏性迁移（D5: B）

不保留 `ui.component` wrapper。Layout 类名直接改为 `frostui.control.interop.*`。

### 4. 保留 ScaledSeekBar

`FrostSliderView` **不** 内嵌 `ScaledSeekBar`。删除 `ScaledSlider` 后 `ScaledSeekBar` 仅服务 `FlankedSeekBar`（工艺视频，本 change 不迁）。

### 5. 资源拆分

| 文件 | 内容 |
|------|------|
| `frostui_control_attrs.xml` | FrostSwitch / FrostCheckbox / FrostSlider styleable |
| `frostui_control_colors.xml` | switch_open 等 |
| `frostui_control_dimens.xml` | track/thumb/checkbox 尺寸 |
| 样式 | `FrostSwitch`、`FrostCheckbox` 对标 `LwsSwitch` / `LwsCheckbox` |

### 6. Java interop API

| View | 关键 API |
|------|----------|
| `FrostSwitchView` | `Checkable`；`setOnCheckedChangeListener((Boolean) -> Unit)` |
| `FrostCheckboxView` | 同上 + `labelText` XML |
| `FrostSliderView` | `setProgress`/`getProgress`、`setMax`、`setOnSeekBarChangeListener`（与 `AdvancedSettingFragment` 对齐） |

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Compose 与旧 View 逐像素漂移 | D12: A；迁移页截图对比；token 从旧 styleable 逐项迁入 |
| 删 `Switch.java` 漏改引用 | grep `ui.component.Switch`；含 `activity_bluetooth.xml` |
| 删 `ScaledSlider` 破坏高级设置绑定 | 先改 `AdvancedSettingFragment` 再删类 |
| `ScaledSeekBar` 误删导致 `FlankedSeekBar` 编译失败 | 明确保留；Code review checklist |
| frostui 反向依赖 ui | 禁止 import `com.lasercyber.lws.ui`；可选 lint |

## Migration Plan

```
Phase 0  OpenSpec + frostui_control_* + control 包空壳
Phase 1  FrostSwitch + FrostCheckbox Compose + interop + 单元测试
Phase 2  迁移 6 Switch + 5 Checkbox layout；改 Java；删 Switch/Checkbox
Phase 3  FrostSlider + 迁移 fragment_advanced_setting.xml；改 AdvancedSettingFragment
Phase 4  删 ScaledSlider.java；确认 ScaledSeekBar 仍编译
Phase 5  make sync；逐页验收（通用设置、高级设置、WiFi/蓝牙、安全须知、对话框）
```

**回滚**：`frost-ui` 分支 revert；不合 `dev` 前无生产影响。

## Open Questions

无（决策已在 `docs/frostui-control-primitives-design.md` §10 关闭）。
