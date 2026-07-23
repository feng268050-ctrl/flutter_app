# FrostUI 控件原语设计（Switch / Checkbox / Select / Slider）

本文档描述将 LWS HMI 中分散的 **Switch、Checkbox、Select、Slider** 能力抽象为独立、可复用组件的设计与实现思路。

**文档性质**：**已确认决策**（2026-06-15）。范围与约束见 [§3 已确认范围](#3-已确认范围与约束)、[§10 决策记录](#10-决策记录)。

**相关文档与代码**：

- 现有 FrostUI 框架：`docs/frostui-compose-refactor-design.md`、`openspec/changes/frostui-compose-framework/`
- 已实现 FrostUI 层：`app/src/main/kotlin/com/lasercyber/lws/frostui/`（`border` / `card` / `dialog`）
- 现有自定义控件：`app/src/main/java/com/lasercyber/lws/ui/component/`
- 设计规范：`openspec/specs/frosted-glass-components/spec.md`

---

## 1. 背景与动机

当前项目中，表单类交互控件分散在 `ui.component` 与各业务模块（快捷模式、工程师模式、设置页），存在以下客观情况：

1. **Switch、Checkbox** 为自研 `View`（非 Material 标准控件），样式 token 已在 `attrs.xml` / `styles.xml`（`LwsSwitch`、`LwsCheckbox`）中定义。
2. **Slider** 无统一类名，由 `ScaledSlider`、`ScaledSeekBar`、`FlankedSeekBar`、`CircularSeekBar`、`ArcSlider` 及系统 `SeekBar` 分别承担不同场景。
3. **Select** 无名为 `Select` 的组件；选择能力由 `Spinner`、`WheelView`、`FrostedGlassPopupMenu`、`GearPick*`、`ThicknessPick*` 等多套实现承担。
4. **Icons** 以 `drawable` / `mipmap` 业务资源为主；项目未引入 Google **Material Icons** 字体库（无 `material-icons-extended` 依赖，代码中无 `MaterialIcons` / `ImageVector` 用法）。

FrostUI 已完成 Card / Button / Dialog 的 Compose 化与 `interop` 桥接（如 `FrostCardView`、`FrostButtonView`）。将 Switch / Checkbox / Select / Slider 纳入同一设计系统，有利于：

- 统一视觉 token 与交互（点击音、无障碍、动画）
- 降低 XML / Java 页面与多套选择器之间的维护成本
- 与 `frostui` 依赖边界（不依赖 `ui`）保持一致

---

## 2. 现状调研（已核实）

### 2.1 Switch

| 项 | 内容 |
|----|------|
| 实现类 | `com.lasercyber.lws.ui.component.Switch` |
| 行为 | 胶囊轨道 + 滑块，实现 `Checkable`，Canvas 自绘 |
| XML 样式 | `LwsSwitch`（`styles.xml`） |
| 自定义属性 | `declare-styleable name="Switch"`（`attrs.xml`） |
| 布局引用（约） | 6 个 layout 文件，共 13 处类名引用：`fragment_common_settings`、`fragment_advanced_setting`（6）、`fragment_date_time_setting`（2）、`activity_wifi`、`activity_bluetooth`、`fragment_network_setting` |
| Java 引用 | 如 `WifiActivity` 等 |

### 2.2 Checkbox

| 项 | 内容 |
|----|------|
| 实现类 | `com.lasercyber.lws.ui.component.Checkbox` |
| 行为 | 圆形复选框 + 动画勾选 + 可选 `labelText` |
| XML 样式 | `LwsCheckbox` |
| 自定义属性 | `declare-styleable name="Checkbox"` |
| 布局引用（约） | 5 个 layout：`frosted_glass_action_*`、`activity_safety_tips`、`activity_use_safety_tips`、`frosted_glass_body_boot_self_check` |
| Java 引用 | `FrostedGlassPromptDialog`、`ReminderExactBuilder`、`BootSelfCheckDialog` 等 |

### 2.3 Slider（线性 / 环形 / 弧形）

| 组件 | 路径 | 主要场景 |
|------|------|----------|
| `ScaledSlider` + `ScaledSeekBar` | `ui.component` | 高级设置（`fragment_advanced_setting.xml` 约 20 处 `ScaledSlider`） |
| `FlankedSeekBar` | `ui.component` | 工艺视频进度（左右时间标签） |
| `CircularSeekBar` | `ui.component` | 快捷模式档位/厚度（`gear_pick.xml`、`thickness_pick.xml` 等） |
| `ArcSlider` | `ui.component` | 弧形滑块（引用较少） |
| `android.widget.SeekBar` | 系统 | 状态对话框、上传进度等 |

### 2.4 Select（分散实现）

| 实现 | 路径 | 主要场景 |
|------|------|----------|
| `Spinner` + `IconSpinnerAdapter` | 系统 + `ui.component.adapter` | 屏幕显示、工程师材料等（`SpinnerBuilder`） |
| `WheelView` / `WheelViewDialog` | `ui.component.wheelview` | 快捷模式档位、厚度、偏移等 |
| `FrostedGlassPopupMenu` | `ui.component.popup` | 锚定列表式弹出菜单 |
| `GearPick` / `GearPickV2` | `quick.mode.component` | 档位选择（环形或滚轮） |
| `ThicknessPick` / `ThicknessPickV2` | `quick.mode.component` | 厚度选择 |
| `SpinnerDropDownPopup` | `ui.component` | 数字/列表下拉 |
| `CustomizeDataPicker` | `ui.component` | 通用数据选择 |
| `DataListPopup` | `engineer.mode.component` | 工程师数据列表弹窗 |
| `RadioButton` / `AppCompatRadioButton` | 系统 / AppCompat | 通用设置中的互斥选项（语言、格式等） |

### 2.5 Icons

- 矢量示例：`res/drawable/ic_*.xml`（WiFi、蓝牙、播放控制等，约 18 个）
- 业务 selector / 位图：`drawable/`、`mipmap/` 大量业务图标
- **无** 统一的 `Icons` 组件库或 Material Icons 依赖

### 2.6 与现有 FrostUI 的关系

| 已有能力 | 可复用点 |
|----------|----------|
| `FrostButton` / `FrostButtonView` | Compose + `AbstractComposeView` interop 模式 |
| `FrostUiClickSoundRegistry` | 可点击控件的点击音 |
| `border` token（`FrostColors`、`FrostDimens`） | 控件颜色/尺寸可扩展或并行 `FrostControl*` token |
| `FrostCard` / frosted panel | 本 change 不涉及 Select |

已确认新增第四层 **`frostui.control`**（D2: A）；须同步修订 `docs/frostui-compose-refactor-design.md` 与 OpenSpec。

---

## 3. 已确认范围与约束

> 决策全文见 [§10 决策记录](#10-决策记录)。**D1: D**（Switch + Checkbox + 线性 Slider）与 **D6: 纳入** 一致。

### 3.1 本 change 交付内容

| 控件 | 是否交付 | 说明 |
|------|----------|------|
| **FrostSwitch** | ✅ | Compose + `FrostSwitchView` |
| **FrostCheckbox** | ✅ | Compose + `FrostCheckboxView` |
| **FrostSlider（线性）** | ✅ | 对标 `ScaledSlider`；Compose + `FrostSliderView`（不依赖保留的 `ScaledSeekBar`） |
| FlankedSeekBar | ❌ | D7：不纳入 |
| GearPickV2 / ThicknessPickV2 | ❌ | D8：不纳入 |
| FrostSelect / Spinner | ❌ | D9：不做了 |
| FrostedGlassPopupMenu 迁移 | ❌ | D10：不纳入 |
| Icons / Material Icons | ❌ | D16：不做 |

### 3.2 包与分支

- **包路径**：`com.lasercyber.lws.frostui.control`（D2: A）
- **工作分支**：仅 **`frost-ui`**，本阶段 **不合入 `dev`**（D14: A）
- **OpenSpec**：需新建 `openspec/changes/frostui-control-primitives/`（D15: A）

### 3.3 迁移 layout 清单（必须改类名）

**Switch**（D3 + **补迁移**，共 **6** 个文件，覆盖全部 `Switch` layout 引用）：

- `fragment_common_settings.xml`
- `fragment_advanced_setting.xml`
- `fragment_date_time_setting.xml`
- `fragment_network_setting.xml`
- `activity_wifi.xml`
- `activity_bluetooth.xml`（补迁移，见 §10 补充决策）

**Checkbox**（D4，共 5 个文件，全部）：

- `frosted_glass_action_laser_enable_reminder.xml`
- `frosted_glass_action_prompt.xml`
- `frosted_glass_body_boot_self_check.xml`
- `activity_safety_tips.xml`
- `activity_use_safety_tips.xml`

**Slider（线性）**（D6: 纳入；仅 `fragment_advanced_setting.xml`，约 20 处 `ScaledSlider`）：

- `fragment_advanced_setting.xml`（与 D3 中 Switch 的 6 处同在本文档）

### 3.4 旧类处理（D5: B）

| 旧类 | 处理 |
|------|------|
| `ui.component.Switch` | **删除**；layout 改 `FrostSwitchView` |
| `ui.component.Checkbox` | **删除**；layout 改 `FrostCheckboxView` |
| `ui.component.ScaledSlider` | **删除**；layout 改 `FrostSliderView` |
| `ui.component.ScaledSeekBar` | **保留**在 `ui.component`（供 `FlankedSeekBar` / 工艺视频使用；本 change 不删） |

- **不** 保留 `@Deprecated` wrapper

### 3.5 验收标准（D12: A）

- **Switch / Checkbox**：与现网逐像素一致（`LwsSwitch` / `LwsCheckbox` token）；动画 **200ms**
- **Slider（线性）**：轨道/拇指对齐 `scaled_seekbar_progress.xml`、`scaled_seekbar_thumb.xml`；min/max/zero 刻度标签位置与现 `ScaledSlider` 一致
- 迁移页在 emulator/真机与改前截图对比

### 3.6 明确不做

- `fragment_common_settings.xml` 内 12 个 `RadioButton` **保持原样**（D11）
- 工程师模式选中色 / `FrostControlTheme`：本 change **不适用**（D13；且 D10 不纳入 Popup）

### 3.7 补充决策（已关闭）

| 事项 | 决策 | 状态 |
|------|------|------|
| 蓝牙页 `activity_bluetooth.xml` | **补迁移** → `FrostSwitchView` | ✅ 与 D5 删 `Switch.java` 一致 |
| `ScaledSeekBar.java` | **保留**在 `ui.component` | ✅ `FlankedSeekBar` 继续可用 |

---

## 3bis. 目标与非目标（归档）

### 目标

- 在 `frostui.control` 提供 **Switch、Checkbox、线性 Slider** 的 Compose 实现与 `interop` View
- token 收敛到 `frostui_control_*.xml`
- `frostui` 不依赖 `ui` / `ai`

### 非目标

- 不新建 `:frostui` Gradle 模块
- 本 change **不含** FlankedSeekBar、Select、Icons（见 §3.1）
- 不合入 `dev`（本阶段）
- 不迁移 `EngineerModelThemeColors`、不替换 `RadioButton`

---

## 4. 包结构与依赖（已确认 D2: A）

```
app/src/main/kotlin/com/lasercyber/lws/frostui/
├── border/
├── card/
├── dialog/
└── control/
    ├── FrostControlColors.kt
    ├── FrostControlDimens.kt
    ├── FrostSwitch.kt
    ├── FrostCheckbox.kt
    ├── FrostSlider.kt          # 本 change：仅 LINEAR 变体
    └── interop/
        ├── FrostSwitchView.kt
        ├── FrostSwitchAttrs.kt
        ├── FrostCheckboxView.kt
        ├── FrostCheckboxAttrs.kt
        ├── FrostSliderView.kt
        └── FrostSliderAttrs.kt
```

**本 change 不创建**：`FrostSelect.kt`（D9 不做了）。

**依赖**：`control → border`；`control ↛ ui / ai`。

### 4.1 资源文件

| 文件 | 内容 |
|------|------|
| `frostui_control_attrs.xml` | `FrostSwitch`、`FrostCheckbox`、`FrostSlider` 的 `declare-styleable`（含 `scaleMinText` 等，自 `ScaledSlider` styleable 迁入） |
| `frostui_control_dimens.xml` | switch / checkbox / seekbar 尺寸 |
| `frostui_control_colors.xml` | 控件色 |
| 样式 | `FrostSwitch`、`FrostCheckbox`（对标 `LwsSwitch` / `LwsCheckbox`） |

迁移完成后删除 `attrs.xml` 中旧 `Switch` / `Checkbox` / `ScaledSlider` styleable（与删旧 Java 类同期）。

---

## 5. 实现模式（沿用 FrostUI 既有范式）

每个控件建议遵循与 `FrostButton` / `FrostButtonView` 相同的分层：

```
┌─────────────────────────────────────────┐
│  Compose @Composable（视觉与交互唯一源）   │
├─────────────────────────────────────────┤
│  interop *View（AbstractComposeView）    │
│  - XML 属性解析（*Attrs.kt）              │
│  - Java：Checkable + OnCheckedChange     │
└─────────────────────────────────────────┘
```

**无** `ui.component` wrapper 层（D5: B，旧类删除）。

**点击音**：状态切换时调用 `FrostUiClickSoundRegistry`（与 `FrostButton` 一致）。

**Java listener**：`FrostSwitchView` / `FrostCheckboxView` 提供 `setOnCheckedChangeListener { checked -> }`；若现有 Java 使用 `CompoundButton.OnCheckedChangeListener`，在迁移 Fragment 时一并改调用方。

---

## 6. 组件设计（本 change 范围）

### 6.1 FrostSwitch

**对标现有**：`ui.component.Switch`、`LwsSwitch` token。

**Compose API（草案）**：

```kotlin
@Composable
fun FrostSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
)
```

**Interop（草案）**：

- 类名：`FrostSwitchView`
- 实现 `android.widget.Checkable`
- 支持 XML：`android:checked` 及现有 switch 颜色/尺寸属性（迁移自 `attrs.xml`）
- Java：`setOnCheckedChangeListener((Boolean) -> Unit)`；实现 `Checkable`

**实现要点**：

- Compose `Canvas` + `animateFloatAsState`，动画 **200ms**（对齐 `LwsSwitch`）
- token 来自 `frostui_control_*`；视觉验收 **逐像素一致**（D12: A）

**迁移 layout**：见 [§3.3 Switch 清单](#33-迁移-layout-清单必须改类名)

---

### 6.2 FrostCheckbox

**对标现有**：`ui.component.Checkbox`、`LwsCheckbox`。

**Compose API（草案）**：

```kotlin
@Composable
fun FrostCheckbox(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    enabled: Boolean = true,
)
```

**Interop（草案）**：

- 类名：`FrostCheckboxView`
- XML：`labelText`、`android:checked`（自 `frostui_control_attrs.xml`）

**迁移 layout**：见 §3.3 Checkbox 清单。

**关联 Java**：`FrostedGlassPromptDialog`、`BootSelfCheckDialog`、`ReminderExactBuilder`、`SafetyTipsActivity`、`UseSafetyTipsActivity` 等。

---

### 6.3 FrostSlider（线性，D6: 纳入）

**对标现有**：`ScaledSlider`；轨道/拇指视觉对齐 `scaled_seekbar_progress.xml`、`scaled_seekbar_thumb.xml`（Compose 自绘，**不**嵌入保留的 `ScaledSeekBar`）。

**Compose API（草案）**：

```kotlin
@Composable
fun FrostSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    steps: Int = 0,
    scaleMinLabel: String? = null,
    scaleMaxLabel: String? = null,
    scaleZeroLabel: String? = null,
)
```

**Interop（草案）**：

- 类名：`FrostSliderView`（`LinearLayout` 或等价容器，内嵌 Compose 滑块 + 刻度行）
- XML 属性：迁移自 `ScaledSlider` styleable（`scaleMinText`、`scaleMaxText`、`scaleZeroText` 等）
- Java：`setProgress` / `getProgress`、`setMax`、`setOnSeekBarChangeListener`（与 `AdvancedSettingFragment` 现有绑定方式对齐，实施时 grep 确认）

**实现要点**：

- 首版 **仅 LINEAR**；不实现 `FLANKED` / `CIRCULAR`（D7、D8 不纳入）
- 视觉验收逐像素一致（D12: A）

**迁移 layout**：`fragment_advanced_setting.xml`（约 20 处 `ScaledSlider` → `FrostSliderView`）

**关联 Java**：`AdvancedSettingFragment` 中对 `ScaledSlider` / `ScaledSeekBar` 的 `findViewById`、listener 改为 `FrostSliderView` API。

---

### 6.4 后续 change（本阶段不实施）

以下保留供 **Select / 其他 Slider 变体** 后续 change 参考：

<details>
<summary>FrostSelect、FlankedSeekBar、CircularSeekBar 草案（点击展开）</summary>

#### FrostSelect（D9 不做了）

```kotlin
enum class FrostSelectMode { DROPDOWN, POPUP, WHEEL }
```

#### 其他 Slider 变体（D7/D8 不纳入）

- `FlankedSeekBar` → `activity_process_video_details.xml`
- `CircularSeekBar` → 快捷模式 gear/thickness

</details>

---

## 7. 与旧代码的兼容策略

### 7.1 已确认：删除旧类（D5: B）

| 旧类 | 处理 |
|------|------|
| `ui.component.Switch` | **删除** → `FrostSwitchView` |
| `ui.component.Checkbox` | **删除** → `FrostCheckboxView` |
| `ui.component.ScaledSlider` | **删除** → `FrostSliderView` |
| `ui.component.ScaledSeekBar` | **保留**在 `ui.component`（`FlankedSeekBar` 专用；本 change 不删） |

### 7.2 XML 替换示例（目标态）

```xml
<!-- 当前 -->
<com.lasercyber.lws.ui.component.Switch
    style="@style/LwsSwitch"
    android:checked="false" />

<!-- 目标（类名待最终确认） -->
<com.lasercyber.lws.frostui.control.interop.FrostSwitchView
    style="@style/FrostSwitch"
    android:checked="false" />
```

### 7.3 OpenSpec（D15: A）

新建 `openspec/changes/frostui-control-primitives/`，与本文档同步维护。

---

## 8. 测试与验收

| 类型 | 内容 |
|------|------|
| 单元测试 | Switch/Checkbox 回调；Slider value clamp、enabled=false |
| 视觉回归 | Switch 开/关、Checkbox 勾选、Slider 轨道/刻度（**D12: A 逐像素**） |
| 互操作 | `AdvancedSettingFragment` 等 Java 绑定 |
| 设备验证 | `make sync`；通用设置、高级设置、安全须知、对话框 |

---

## 9. 实施阶段（已批准范围）

```
Phase 0  OpenSpec + control 包骨架 + frostui_control_* 资源
Phase 1  FrostSwitch + FrostCheckbox（Compose + interop）
Phase 2  迁移 §3.3 全部 Switch / Checkbox layout + 删 Switch.java / Checkbox.java
Phase 3  FrostSlider LINEAR + 迁移 fragment_advanced_setting.xml
Phase 4  删 ScaledSlider.java（**保留** ScaledSeekBar.java）
Phase 5  全量验收（D12: A）
```

**不在本 change**：Phase 原草案中的 Select、FlankedSeekBar、WHEEL（D7～D11）。

---

## 10. 决策记录

| 题号 | 回复 | 生效含义 |
|------|------|----------|
| **D1** | **D** | Switch + Checkbox + **线性 Slider**（与 D6 纳入一致） |
| **D2** | **A** | 包路径 `com.lasercyber.lws.frostui.control` |
| **D3** | 见下表 + 蓝牙补迁移 | Switch 迁移 **6** 个 layout（含 `activity_bluetooth.xml`） |
| **D4** | 见下表 | Checkbox 迁移全部 5 个 layout |
| **D5** | **B** | 删除旧 Java 类，XML 直接改 `Frost*View` 类名 |
| **D6** | **纳入**（2026-06-15 修订） | `fragment_advanced_setting.xml` 约 20 处 `ScaledSlider` → `FrostSliderView` |
| **D7** | 不纳入 | `FlankedSeekBar` / 工艺视频不动 |
| **D8** | 不纳入 | `GearPickV2` / `ThicknessPickV2` 不动 |
| **D9** | 不做了 | 不做 FrostSelect / Spinner 替换 |
| **D10** | 不纳入 | `FrostedGlassPopupMenu` 不动 |
| **D11** | 保持 RadioButton | 通用设置 12 个 `RadioButton` 不动 |
| **D12** | **A** | 逐像素验收 |
| **D13** | 不适用 | |
| **D14** | **A** | 仅 `frost-ui` 分支，本阶段不合 `dev` |
| **D15** | **A** | 新建 OpenSpec `frostui-control-primitives` |
| **D16** | **A** | 不做 Icons / Material Icons |

### D3 确认的 Switch layout（6 个）

- `fragment_common_settings.xml`
- `fragment_advanced_setting.xml`
- `fragment_date_time_setting.xml`
- `fragment_network_setting.xml`
- `activity_wifi.xml`
- `activity_bluetooth.xml`（补充决策：补迁移）

### D4 确认的 Checkbox layout

- `frosted_glass_action_laser_enable_reminder.xml`
- `frosted_glass_action_prompt.xml`
- `frosted_glass_body_boot_self_check.xml`
- `activity_safety_tips.xml`
- `activity_use_safety_tips.xml`

### D6 确认的 Slider layout

- `fragment_advanced_setting.xml`（`ScaledSlider` → `FrostSliderView`）

### 补充决策（2026-06-15）

| 事项 | 决策 |
|------|------|
| 蓝牙页 Switch | **补迁移** `activity_bluetooth.xml` |
| `ScaledSeekBar` | **保留**在 `ui.component`（不删、不迁入 frostui） |

**关联 Java**（Switch 迁移须一并改）：`WifiActivity`、`BluetoothManagerActivity` 等中对 `Switch` 的 import / `findViewById` 类型。

---

## 11. 附录：引用点速查

便于评估工作量（统计基于当前仓库 layout / 主要 Java 引用，迁移时须再 grep 确认）。

| 旧实现 | 约略 XML 引用规模 | 主要文件 |
|--------|-------------------|----------|
| `Switch` | 6 layouts / 13 tags | `fragment_advanced_setting`、`fragment_common_settings` 等 |
| `Checkbox` | 5 layouts | `frosted_glass_action_*`、安全须知 |
| `ScaledSlider` | 1 layout / ~20 tags | `fragment_advanced_setting` |
| `CircularSeekBar` | 多个 layout | `gear_pick`、`thickness_pick`、`laser_progress` |
| `Spinner` | 少量 | `fragment_screen_display` 等 |
| `WheelView` | 快捷模式多处 | `fragment_general_operations`、`activity_quick_mode` |

---

## 12. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-15 | 初稿：基于代码现状与 FrostUI 架构整理；待确认项集中于 §10 |
| 2026-06-15 | §10 改为 D1～D16：附具体 layout 路径、选项表与回复模板 |
| 2026-06-15 | 补充决策：蓝牙页补迁移；`ScaledSeekBar` 保留在 `ui.component` |
