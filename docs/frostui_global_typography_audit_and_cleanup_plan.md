# FrostUI 全局字号规范检查与收口方案

## 1. 目标

统一 `app/lws_hmi/lib` 中标题、正文、列表、说明、按钮、Tab、Dialog、数据指标、仪表盘等文字的字号来源，确保业务页面不再直接维护裸字号或通过 `copyWith(fontSize: ...)` 覆盖全局 Typography。

核心原则：

> **一个视觉角色只有一个字号来源（Single Source of Truth, SoT）。**

业务 Widget 应优先引用 `HmiTypography` 的语义角色；`AppTypography` 只负责基础字号阶梯；特殊 Dashboard / Gauge / Clock 使用独立的 Display Typography 体系。

---

## 2. 当前总体结论

当前项目已经建立主要字号体系：

```text
AppTypography
      ↓
HmiTypography / HmiDisplayTypography
      ↓
context.hmiTypography.<semanticRole>
      ↓
业务组件
```

主体架构正确，页面标题、Section 标题、Settings 列表、正文、普通说明、Button、Dialog、Tab、Metric 等已经大面积使用全局 Typography。

当前剩余问题主要集中在：

1. 少量生产代码仍存在直接 `fontSize: <number>`。
2. 部分业务模块虽然定义了自己的字号常量，但数字实际与全局字号重复，形成第二字号来源。
3. 部分代码通过 `supporting.copyWith(fontSize: 22)` 等方式覆盖语义字号。
4. Gauge / CustomPainter / 自适应统计卡片等特殊显示型文字尚未完全收口。
5. 特殊视觉角色需要正式建立语义 Token，而不是继续使用局部数字。
6. 建议增加 CI / lint，禁止业务代码重新引入裸字号。

---

# 3. 全局基础字号阶梯

当前基础字号按照 `AppTypography` 统一管理：

| 视觉层级 | 推荐 Token | 100% 基准字号 |
|---|---|---:|
| Technical / Micro | `micro` | 12 |
| Caption | `caption` | 14 |
| Supporting | `supporting` | 16 |
| Body | `body` | 18 |
| Control / List | `control` | 20 |
| Section Title | `sectionTitle` | 22 |
| Navigation | `navigation` | 24 |
| Page Title | `pageTitle` | 28 |
| Dialog Title | `dialogTitle` | 32 |
| Large Dialog Title | `largeDialogTitle` | 36 |
| Display | `display` | 44 |
| Critical Title | `criticalTitle` | 52 |

基础字号只描述**字号阶梯**，不建议业务页面直接根据数字选择字号。

例如业务代码不要写：

```dart
style: AppTypography.sectionTitle
```

更推荐：

```dart
style: context.hmiTypography.sectionTitle
```

---

# 4. 业务层语义字号规范

业务页面统一通过 `HmiTypography` 选择视觉角色。

推荐标准：

```dart
// 页面标题
context.hmiTypography.pageTitle

// Section / Card 标题
context.hmiTypography.sectionTitle

// 普通正文
context.hmiTypography.body

// 普通辅助说明
context.hmiTypography.supporting

// Caption
context.hmiTypography.caption

// Settings 列表
context.hmiTypography.settingsRowTitle
context.hmiTypography.settingsRowValue

// Tab
context.hmiTypography.primaryTabLabel

// 数据指标
context.hmiTypography.metricLabel
context.hmiTypography.metricValue
context.hmiTypography.metricUnit

// Dialog
context.hmiTypography.dialogTitle
context.hmiTypography.dialogBody
```

禁止业务页面直接维护：

```dart
TextStyle(fontSize: 22)
```

也禁止：

```dart
context.hmiTypography.body.copyWith(
  fontSize: 22,
)
```

后者虽然引用了全局 Typography，但实际字号仍由业务页面决定，依然破坏 SoT。

---

# 5. 本次新增确认：两类说明文字统一为 22

本次明确调整以下两类文字：

## 5.1 升级页中部说明

升级页面中位于主要内容区域的说明文字，原先使用约 `16` 的 Supporting 字号，实际 HMI 阅读距离下偏小。

调整为：

```text
Upgrade Description = 22
```

建议新增正式语义角色：

```dart
HmiTypography.upgradeDescription
```

底层映射：

```dart
upgradeDescription = AppTypography.sectionTitle;
```

业务页面使用：

```dart
Text(
  description,
  style: context.hmiTypography.upgradeDescription.copyWith(
    color: CyberColors.textSecondary,
  ),
)
```

不要继续使用：

```dart
context.hmiTypography.supporting.copyWith(
  fontSize: 22,
)
```

### 适用范围

包括但不限于：

- HMI Upgrade 页面中部升级说明；
- Camera Program Upgrade 页面中部说明；
- 同类型 OTA / Firmware Upgrade 主说明区域。

这些内容虽然属于“说明”，但在工业 HMI 中承担重要操作引导作用，视觉层级高于普通 Supporting Text，因此允许使用 `22`。

---

## 5.2 卡片下方脚注 `SettingsHelpFooter`

`SettingsHelpFooter` 当前视觉定位属于设置卡片下方的重要帮助说明，不再按照普通 Supporting `16` 处理。

调整为：

```text
SettingsHelpFooter = 20
```

建议正式定义：

```dart
HmiTypography.settingsHelpFooter
```

底层映射：

```dart
settingsHelpFooter = AppTypography.control;
```

组件内部直接：

```dart
Text(
  text,
  style: context.hmiTypography.settingsHelpFooter.copyWith(
    color: CyberColors.textSecondary,
  ),
)
```

删除类似：

```dart
static const helpTextSize = 22;
```

以及：

```dart
context.hmiTypography.supporting.copyWith(
  fontSize: helpTextSize,
)
```

最终应形成：

```text
SettingsHelpFooter
        ↓
HmiTypography.settingsHelpFooter
        ↓
AppTypography.sectionTitle = 22
```

---

# 6. 为什么 Upgrade Description 和 SettingsHelpFooter 都是 22，但仍建议两个 Token

虽然两者当前基准字号都为 `22`，仍建议分别建立：

```dart
upgradeDescription
settingsHelpFooter
```

而不是共用一个模糊的：

```dart
largeSupporting
```

原因是：

> **字号相同不代表视觉角色相同。**

未来设计可能调整：

```text
Upgrade Description   22 → 24
Settings Help Footer  22 → 20
```

如果两者共用同一个 Token，就会产生不必要的耦合。

推荐关系：

```text
Semantic Role                    Base Scale
------------------------------------------------
upgradeDescription        ─────→ sectionTitle 22
settingsHelpFooter        ─────→ control 20
```

即语义独立，当前可以映射到同一个基础字号。

---

# 7. 需要清理的裸字号

当前升级相关页面存在典型写法：

```dart
context.hmiTypography.settingsRowTitle.copyWith(
  fontSize: 22,
)
```

以及：

```dart
context.hmiTypography.settingsRowTitle.copyWith(
  fontSize: 20,
)
```

应分别处理。

### 原 `22`

如果属于升级页中部说明：

```dart
context.hmiTypography.upgradeDescription
```

如果属于 Section 标题：

```dart
context.hmiTypography.sectionTitle
```

### 原 `20`

如果本身就是 Settings Row：

```dart
context.hmiTypography.settingsRowTitle
```

直接删除 `fontSize: 20`。

原则：

```text
不要通过数字反推角色；
先确定视觉角色，再引用对应 Typography Token。
```

---

# 8. Settings 说明文字规范重新划分

原先统一认为：

```text
Supporting = 16
```

这个规则需要细化。

## 普通辅助说明

例如：

- 次要状态；
- 不影响操作理解的补充信息；
- 较弱提示；
- Card 内辅助 Label。

继续使用：

```dart
context.hmiTypography.supporting
```

基准：

```text
16
```

## 重要帮助说明

例如：

- `SettingsHelpFooter`
- 设置操作后的重要解释；
- 工业设备配置相关风险 / 使用说明；
- 用户需要在正常阅读距离下持续阅读的说明。

统一：

```dart
context.hmiTypography.settingsHelpFooter
```

基准：

```text
22
```

因此不要建立：

```text
所有 Description = 16
```

这种简单规则。

应该按语义层级划分。

---

# 9. 升级页面 Typography 推荐结构

升级页面推荐统一：

```text
Upgrade Page
│
├── Page Title
│   └── pageTitle
│
├── Package / Version Section
│   ├── sectionTitle
│   └── body / settingsRowValue
│
├── Upgrade Description
│   └── upgradeDescription = 22
│
├── Progress / Status
│   ├── metricValue
│   └── supporting / status role
│
└── Action Buttons
    └── HmiButton Typography
```

不要在 HMI Upgrade 和 Camera Upgrade 两套页面分别定义：

```text
descriptionSize = 22
instructionSize = 22
helpSize = 22
```

统一归入：

```dart
HmiTypography.upgradeDescription
```

---

# 10. 局部重复字号常量需要回归全局 Token

项目中仍存在类似：

```dart
static const statusLabelFontSize = 20.0;
static const homeLabelFontSize = 24.0;
```

以及：

```dart
wheelSelectedTextSize = 22;
wheelUnselectedTextSize = 20;
dashboardUnitSize = 16;
quickLaserButtonLabelSize = 44;
```

这些数字虽然与全局字号一致，但仍属于重复来源。

建议改为：

```dart
static const statusLabelFontSize =
    AppTypography.controlSize;

static const homeLabelFontSize =
    AppTypography.navigationSize;
```

或者 Widget 可以直接使用语义 Style 时，优先：

```dart
context.hmiTypography.statusBarLabel
context.hmiTypography.statusBarAction
```

---

# 11. Process / Quick Mode 等模块

类似：

```text
22 → sectionTitle
20 → control
18 → body
16 → supporting
12 → micro
24 → navigation
44 → display
```

如果这些字号只是对全局 Scale 的重复，统一引用 `AppTypography.*Size`。

例如：

```dart
static const wheelSelectedTextSize =
    AppTypography.sectionTitleSize;

static const wheelUnselectedTextSize =
    AppTypography.controlSize;

static const dashboardUnitSize =
    AppTypography.supportingSize;
```

如果 Widget 已经有明确业务角色，则更推荐直接使用 `HmiTypography`。

---

# 12. 特殊字号处理原则

项目允许存在非标准阶梯字号，例如：

```text
19
29
33
37
38
41
```

但必须满足：

> **特殊字号可以存在，裸字号不能无归属存在。**

如果确实经过 UI 验证必须保留，应登记为正式语义 Token：

```dart
HmiTypography.processToast
HmiTypography.numericInputValue
HmiTypography.cncGuideTitle
```

而不是散落在业务文件：

```dart
fontSize: 38
```

---

# 13. Gauge / Dashboard / Clock 不直接套普通正文体系

仪表盘、时钟、大型数据展示属于：

```text
Display Typography
```

不应强制使用普通：

```dart
body
sectionTitle
pageTitle
```

推荐：

```text
HmiDisplayTypography
│
├── clock
├── dashboardValue
├── gaugeValue
├── gaugeUnit
├── gaugeTitle
└── gaugeTickLabel
```

Gauge 如果需要根据直径计算字号，可以保留：

```text
Base Token × Geometry Factor
```

但缩放策略必须统一，不允许每个 Painter 独立决定。

建议：

```text
Gauge Geometry
      ↓
Base Gauge Typography
      ↓
HmiTextScale.displayTextScalerOf(context)
```

---

# 14. Small / Default / Large 缩放规范

Reading Typography：

```text
Small    = 0.90
Default  = 1.00
Large    = 1.12
```

包括：

- Page Title；
- Section Title；
- Settings Row；
- Body；
- Upgrade Description；
- SettingsHelpFooter；
- Button Label；
- Tab；
- Dialog 正文；
- 普通辅助说明。

因此新增的：

```text
upgradeDescription = 22
settingsHelpFooter  = 20
```

在 Large 下仍然通过全局 `TextScaler` 放大：

```text
22 × 1.12 ≈ 24.64
```

不要为它们单独写 Large 字号。

Display Typography 可以继续使用受限缩放策略，例如：

```text
0.95 / 1.00 / 1.05
```

避免超大时钟、Gauge 数字破坏固定 Dashboard。

---

# 15. 禁止的实现方式

## 禁止业务裸字号

```dart
TextStyle(
  fontSize: 22,
)
```

## 禁止通过 copyWith 偷偷改字号

```dart
context.hmiTypography.supporting.copyWith(
  fontSize: 22,
)
```

## 禁止重复声明已经存在的字号

```dart
static const helpTextSize = 22;
```

如果它本质就是 `settingsHelpFooter`，应该由 Typography 提供。

## 禁止 Small / Large 单独维护字号

错误：

```dart
if (large) {
  fontSize = 24.64;
}
```

正确：

```text
22 base
   ↓
MediaQuery.textScaler
   ↓
Large 1.12
```

---

# 16. 推荐 HmiTypography 新增角色

建议至少补充：

```dart
class HmiTypography extends ThemeExtension<HmiTypography> {
  // ...

  final TextStyle upgradeDescription;
  final TextStyle settingsHelpFooter;
}
```

100%：

```dart
upgradeDescription =
    AppTypography.sectionTitle;

settingsHelpFooter =
    AppTypography.control;
```

如果希望强调“22 只是当前视觉值”，可明确注释：

```dart
/// Important explanatory text shown in upgrade workflows.
/// Current 100% baseline: 22.
final TextStyle upgradeDescription;

/// Important help copy rendered below settings cards.
/// Current 100% baseline: 20.
final TextStyle settingsHelpFooter;
```

---

# 17. CI / Lint 建议

现在字号体系已经接近收口，建议增加自动检查。

生产业务目录禁止：

```regex
fontSize\s*:\s*\d
```

同时检查：

```text
.copyWith(
    ...
    fontSize: <number>
)
```

允许裸字号定义的文件建议限制为：

```text
app/theme/app_typography.dart
app/theme/hmi_typography.dart
app/theme/hmi_display_typography.dart
```

CustomPainter / Gauge 如确有动态字号计算，应：

1. 使用集中式 Gauge Typography；
2. 或加入明确白名单；
3. 禁止散落在多个业务 Painter 中独立维护。

---

# 18. 修改优先级

## P0

1. 将升级页中部说明统一为 `22`。
2. 新增 `HmiTypography.upgradeDescription`。
3. 将 `SettingsHelpFooter` 统一为 `20`。
4. 新增 `HmiTypography.settingsHelpFooter`。
5. 清除升级页面现存 `fontSize: 22 / 20` 裸覆盖。
6. 禁止使用 `supporting.copyWith(fontSize: 22)`。

## P1

1. 清理 StatusBar / ProcessMode / QuickMode / Monitor 中与全局 Scale 重复的数字字号。
2. 业务 Widget 统一走 `context.hmiTypography.<role>`。
3. `AppTypography` 不再直接出现在普通业务页面。

## P2

1. 收口 Gauge / Dashboard Typography。
2. 给 19 / 29 / 33 / 37 / 38 / 41 等特殊字号建立正式语义角色。
3. 增加 CI / custom_lint 防止裸字号重新进入项目。

---

# 19. 验收标准

完成后至少满足：

- 页面标题统一引用 `pageTitle`；
- Section 标题统一引用 `sectionTitle`；
- Settings List 统一引用 `settingsRowTitle / settingsRowValue`；
- 普通正文统一引用 `body`；
- 普通弱说明使用 `supporting = 16`；
- **升级页中部重要说明使用 `upgradeDescription = 22`；**
- **卡片下方 `SettingsHelpFooter` 使用 `settingsHelpFooter = 20`；**
- Button 字号由 Button Typography / Metrics 统一管理；
- Tab 字号只有一个来源；
- Dialog Title / Body 使用正式语义角色；
- Gauge / Clock / Dashboard 使用 Display Typography；
- 业务代码无直接 `fontSize: 12/16/18/20/22/24/...`；
- 业务代码不通过 `copyWith(fontSize: number)` 修改全局字号；
- Small / Default / Large 切换后所有 Reading Typography 能统一缩放；
- 不允许为了 Large 模式单独硬编码第二套字号。

---

# 20. 最终推荐架构

```text
                      ┌─────────────────────┐
                      │   AppTypography     │
                      │  基础字号 Scale     │
                      └──────────┬──────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
           HmiTypography              HmiDisplayTypography
           阅读 / 业务语义             Gauge / Clock / Display
                    │                         │
                    ▼                         ▼
       context.hmiTypography.xxx      Display-specific style
                    │                         │
                    └────────────┬────────────┘
                                 ▼
                         Small / Default / Large
```

业务开发只需要回答：

> **“这段文字是什么角色？”**

而不应该回答：

> **“这里应该写 20、22 还是 24？”**

字号数字由 Design System 统一管理。
