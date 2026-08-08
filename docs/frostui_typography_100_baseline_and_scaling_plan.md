# FrostUI 100% 字号基线与“小 / 中 / 大”字号迁移方案

> 基于本次上传的 `lib(5).zip` 代码扫描整理。目标是先把 **100%（Medium）** 做成稳定、可维护的唯一基线，再在此基础上增加 Small / Medium / Large 三档字号。

---

## 1. 结论

当前项目的字体系统已经具备较好的骨架：

- `AppTypography`：基础字号阶梯；
- `HmiTypography`：业务语义字体；
- `HmiButtonMetrics`：按钮尺寸单一数据源；
- `HmiTabMetrics`：一级 Tab 布局参数；
- `HmiDisplayTypography`：时钟、大数值等特殊显示字号。

但在实现三档字号之前，建议先完成 5 个 P0 项：

1. **冻结 100% 语义字号，不再通过“标题字号 → 下一档”推导正文。**
2. **清理剩余 13 处生产代码裸数字字号，改为语义 Token。**
3. **修复 `WordBoundaryLabel` 的 `TextScaler.noScaling` 测量逻辑。**
4. **修复 Tab / StatusBar 等手工 `TextPainter` 测量没有跟随 TextScaler 的问题。**
5. **明确哪些文字允许完整缩放、哪些固定几何显示需要限制缩放。**

完成这些后，再增加 90% / 100% / 112% 三档，风险会明显降低。

---

# 2. 当前 100% 字号体系

## 2.1 `AppTypography` 基础阶梯

当前代码：`lib/app/theme/app_typography.dart`

| Token | 100% 字号 | 当前定位 |
|---|---:|---|
| `micro` | 12 | 技术元数据、极小辅助信息 |
| `caption` | 14 | Caption / 次要说明 |
| `supporting` | 16 | 辅助文案 |
| `body` | 18 | 正文 |
| `control` | 20 | 控件、设置项 |
| `sectionTitle` | 22 | 分组标题 |
| `navigation` | 24 | 一级导航 |
| `pageTitle` | 28 | 页面标题 |
| `dialogTitle` | 32 | 普通弹窗标题 |
| `largeDialogTitle` | 36 | 重要弹窗标题 |
| `display` | 44 | 大型显示文案 |
| `criticalTitle` | 52 | 关键提示标题 |

这套基础阶梯本身可以继续作为 100% 基线，不需要为了三档字号重新设计。

---

## 2.2 `HmiTypography` 已经完成语义层封装

当前已经存在：

```text
pageTitle
sectionTitle
settingsRowTitle
settingsRowValue
body
supporting
caption
technicalMeta

primaryTabLabel
processTabLabel
secondaryTabLabel
compactTabLabel

buttonMini ... buttonJumbo

metricLabel
metricValue
metricUnit

dialogTitle
importantDialogTitle
criticalTitle
criticalBody
```

方向正确：**页面应该选择“角色”，而不是选择字号数字。**

后续 Small / Medium / Large 也应该作用于这些语义角色，而不是页面里重新计算字号。

---

# 3. 当前最需要调整：Tip / Dialog 字号关系

## 3.1 当前问题

`AppTypography` 仍然存在：

```dart
static double tipBodySizeForTitle(double titleSize)
```

它使用：

```text
52 → 44 → 36 → 32 → 28 → 24 → 22 → 20 → 18 → 16 → 14 → 12
```

标题往下取一个字号作为正文。

当前使用位置包括：

```text
alarm_logs_cleared_dialog.dart
operation_failed_dialog.dart
engineer_operation_status_dialog.dart
custom_home_save_success_dialog.dart
laser_enable_reminder_dialog.dart
```

这在只有 100% 时能工作，但不适合作为未来三档字号的核心机制。

### 原因

字号层级应该是：

```text
语义角色 → 基准字号 → 用户缩放
```

而不是：

```text
标题字号 → 查阶梯 → 推导正文 → 再缩放
```

否则后续出现 31.36、40.32 等缩放字号时，会产生“怎么找下一档”的问题。

---

## 3.2 建议改成明确的语义关系

建议补充以下角色：

| 角色 | 100% 建议值 | 当前来源 |
|---|---:|---|
| `dialogTitle` | 32 | 已有 |
| `dialogBody` | 28 | 新增，替代 32 → 28 推导 |
| `importantDialogTitle` | 36 | 已有 |
| `importantDialogBody` | 32 | 新增，替代 36 → 32 推导 |
| `criticalTitle` | 52 | 已有 |
| `engineerTipBody` | 36 | Engineer 入场专用 |
| `safetyTipTitle` | 36 | Safety Tips |
| `safetyTipBody` | 24 | Safety Tips |
| `reminderTitle` | 24 | 激光提醒 |
| `reminderBody` | 22 | 激光提醒卡片文案 |
| `dialogOptionLabel` | 26 | “Don't show again”等选项 |

例如：

```dart
final bodyStyle = context.hmiTypography.dialogBody.copyWith(
  color: CyberColors.textSecondary,
);
```

替代：

```dart
fontSize: AppTypography.tipBodySizeForTitle(titleSize)
```

### 建议处理顺序

先保留 `tipBodySizeForTitle()` 作为 Legacy 兼容函数，但：

- 新代码禁止调用；
- 上述 5 个现有调用逐步迁移；
- 全部迁移后删除该函数和 `sizeLadder` 的“正文推导”职责。

`sizeLadder` 本身仍可用于文档或设计参考，但不应承担业务排版算法。

---

# 4. 特殊弹窗不需要强制套通用梯子

当前代码中有几个合理的特殊字号体系。

## 4.1 Engineer 入场 Tip

当前：

```text
Title = 52
Body  = 36
```

这是明确的视觉设计，可以保留。

不要改成：

```text
52 → ladder 下一档 44
```

应定义成两个独立语义 Token：

```text
engineerTipTitle = 52
engineerTipBody  = 36
```

---

## 4.2 Safety Tips

当前代码实际为：

```text
Title = importantDialogTitle = 36
Body  = navigation = 24
```

同样建议明确成：

```text
safetyTipTitle = 36
safetyTipBody  = 24
```

即使数字与其它 Token 相同，也应按语义引用，不要依赖“Safety 正文刚好等于 navigation”。

---

## 4.3 数字输入 Frost Dialog

当前有明确的特殊规格：

```text
Title       37
Description 29
Input Value 33
Stepper     41
```

这些数值不属于通用 12~52 阶梯，但本身并不是问题。

建议抽成专用 Token：

```text
numericDialogTitle       = 37
numericDialogDescription = 29
numericInputValue        = 33
numericStepperGlyph      = 41
```

原则仍然是：

> 特殊字号可以存在，但必须有名字，不能散落裸数字。

---

# 5. 当前上传代码中的 13 处生产裸字号

排除 Theme、Demo、生成代码后，本包仍有 **13 处直接数字 `fontSize`**。

建议如下处理：

| 当前位置 | 当前字号 | 建议 |
|---|---:|---|
| `boot_self_check_dialog.dart` | 26 | `dialogOptionLabel` |
| `engineer_mode_entry_tips_dialog.dart` checkbox | 26 | `dialogOptionLabel` |
| `laser_enable_reminder_dialog.dart` checkbox | 26 | `dialogOptionLabel` |
| `system_upgrade_page.dart` | 22 | `sectionTitle` |
| `system_upgrade_page.dart` | 20 | `control` / `settingsRowTitle` |
| `control_board_upgrade_page.dart` | 22 | `sectionTitle` |
| `control_board_upgrade_page.dart` | 20 | `control` / `settingsRowTitle` |
| `settings_storage_bar.dart` | 14 | `caption` |
| `settings_pill_dropdown.dart` | 18 | `body` |
| `process_library_page.dart` | 37 | 新增 `formDialogTitle` / `numericDialogTitle` 同级 Token |
| `cyber_ime_numeric_input_dialog.dart` | 29 | `numericDialogDescription` |
| `cyber_ime_numeric_input_dialog.dart` | 33 | `numericInputValue` |
| `cyber_ime_numeric_input_dialog.dart` | 41 | `numericStepperGlyph` |

完成后，可以开始执行：

```text
业务页面禁止直接写 fontSize: 数字
```

Theme / Typography / 专用绘制 Metrics 作为白名单。

---

# 6. 当前 Button 体系基本正确，但有一个基线不一致需要确认

`HmiButtonMetrics` 已经成为按钮高度、minWidth、Padding、Icon 的单一数据源，这部分结构正确。

当前上传包实际代码中的按钮字号为：

| Size | H | Font |
|---|---:|---:|
| mini | 36 | 14 |
| small | 44 | 16 |
| medium | 52 | 20 |
| large | 60 | 24 |
| hero | 68 | **24** |
| jumbo | 88 | 32 |

注意：当前上传包 `HmiTypography.buttonHeroFontSize` 实码还是 **24**。

你此前已经确定 Hero 因显示效果需要使用 **26**，因此冻结 100% 之前建议最终确认：

```dart
static const buttonHeroFontSize = 26.0;
```

否则文档基线和当前代码会继续存在差异。

---

# 7. Tab 体系的进一步优化

当前：

```text
HmiTabMetrics.labelFontSize = 24
HmiTypography.primaryTabLabel = navigation = 24
```

这里出现了两个字号数据源。

建议：

### `HmiTabMetrics` 只负责布局

```text
tabHeight
iconSize
iconLabelGap
horizontalPadding
indicatorHeight
```

### `HmiTypography.primaryTabLabel` 负责文字

即移除 / 不再业务使用：

```dart
HmiTabMetrics.labelFontSize
```

`HmiPrimaryTabContent` 改为：

```dart
final style = context.hmiTypography.primaryTabLabel.copyWith(
  color: color,
  fontWeight: selected
      ? HmiTabMetrics.selectedLabelWeight
      : HmiTabMetrics.labelWeight,
  height: 1,
);
```

这样未来字号切换时不需要同时维护：

```text
HmiTypography.primaryTabLabel
HmiTabMetrics.labelFontSize
```

---

# 8. 三档字号真正的 P0：`WordBoundaryLabel` 当前不支持缩放测量

当前：

```dart
TextPainter(
  ...
  textScaler: TextScaler.noScaling,
)
```

位于：

```text
ui/hmi/word_boundary_label.dart
```

这是未来 Large 字号最容易出现问题的地方之一。

### 当前行为

`WordBoundaryLabel` 先使用 **100% 宽度**计算每个英文单词应该放在哪一行；

随后真正的 `Text` 又会使用页面的 `MediaQuery.textScaler` 绘制。

结果可能出现：

```text
测量时：一行可以放 4 个词
Large 绘制：实际只能放 3 个词
```

最终造成：

- 英文被错误 ellipsis；
- 单词越界；
- 行宽判断错误；
- Safety / Engineer Tip 在 Large 下异常。

### 建议修改

让测量函数显式接受 `TextScaler`：

```dart
static double _measureWidth(
  String text,
  TextStyle style,
  TextScaler textScaler,
)
```

`build()` 中：

```dart
final scaler = MediaQuery.textScalerOf(context);
```

并将 scaler 传入：

```text
spaceWidth
packLines
_measureWidth
```

`WordBoundaryBody` 的 `Wrap.spacing` 同样要使用缩放后的空格宽度。

这是三档字号上线前必须修复的项目。

---

# 9. 手工 `TextPainter` 测量也必须统一 TextScaler

当前并不是所有文字都只是 `Text()`，项目中存在大量手工宽度测量。

## P0：`product_top_tabs.dart`

`_tabWidthFor()` 当前：

```dart
TextPainter(...).layout();
```

没有传 `textScaler`。

但真实 Tab Label 会被 MediaQuery 缩放。

Large 模式可能造成：

```text
计算出来的 Tab 宽度 < 实际文字所需宽度
```

建议：

```dart
textScaler: MediaQuery.textScalerOf(context)
```

并直接使用：

```dart
context.hmiTypography.primaryTabLabel
```

作为测量 TextStyle。

---

## P1：`work_mode_status_bar.dart`

状态栏会手工测量多个状态 Label 宽度，目前同样没有 TextScaler。

Large 下会导致：

- 状态项间距计算错误；
- 提前/延后触发 ellipsis；
- icon 与文字重叠。

建议同步传入 TextScaler。

---

## 已正确处理：Engineer Entry

`resolveCardWidth()` 已经使用：

```dart
textScaler: MediaQuery.textScalerOf(context)
```

这部分方向正确，可以作为其它手工测量的参考。

---

## 已正确处理：CallBackHomeButton

`widthForLabel()` 支持传入 `TextScaler`，`ProductPageStatusBar` 当前也已经使用：

```dart
MediaQuery.textScalerOf(context)
```

保留该方式即可。

---

# 10. 必须建立“允许缩放 / 限制缩放”分类

未来不能简单地让所有内容无差别 × 1.12。

建议分三类。

## A. 完整跟随用户字号

必须跟随 Small / Medium / Large：

```text
页面标题
Tab Label
正文
设置项标题 / Value
按钮 Label
Dialog 标题 / 正文
Safety Tips
Engineer Tips
表单 Label
提示文案
```

这些属于“阅读型 UI 文案”。

---

## B. 跟随字号，但布局需要一起适配

```text
按钮
Tab
设置行
弹窗
输入框
Dropdown
状态栏
```

不能只放大文字，还需要检查：

```text
minHeight
minWidth
horizontalPadding
card padding
Dialog maxHeight
可滚动区域
```

第一版建议文字档位：

```text
Small  = 0.90
Medium = 1.00
Large  = 1.12
```

幅度不要过大。

---

## C. 固定几何 / Display 内容，需要明确限制策略

包括：

```text
Home Clock
Dashboard 大数值
Gauge 刻度
Process Wheel
Ramp Chart Axis
CustomPainter 内文字
```

这些文字的位置直接参与图形几何计算。

例如当前已有：

```text
HmiDisplayTypography.clockSize = 120
HmiDisplayTypography.dashboardValueSize = 68
```

建议明确：

```text
普通 UI：0.90 / 1.00 / 1.12
Display / 图表：0.95 / 1.00 / 1.05（或保持 1.00）
```

不要让 `120 × 1.12 = 134.4` 直接破坏 Home 排版。

重点是：**必须明确为产品规则，而不是代码碰巧没有缩放。**

---

# 11. Home Quick Action 需要特殊处理

`homeQuickActionLabelFontSize()` 当前通过 `TextPainter` 二分查找“刚好能塞进卡片”的字号。

如果根节点再加 `TextScaler.linear(1.12)`：

```text
函数按 100% 计算一个刚好可放入的字号
↓
Text 绘制时再次 ×1.12
↓
发生 ellipsis
```

这里需要提前决定产品策略：

### 推荐方案

Home Quick Action 属于固定视觉卡片，使用 **clamped scaling**：

```text
最大 1.05
```

或者让计算函数把 `TextScaler` 纳入宽度测量。

不建议出现“算法先 fit，再被 MediaQuery 二次放大”的情况。

---

# 12. `HmiDisplayTypography` 与 `HmiTypography` 当前存在重复数据源

当前：

`HmiDisplayTypography`：

```text
clock = 120
dashboardValue = 68
```

而 `HmiTypography` 内部又写了一次：

```text
_clock = 120
_dashboardValue = 68
```

目前 `context.hmiTypography.clock` / `dashboardValue` 基本没有业务调用。

建议二选一：

### 推荐

Display 类字号统一由：

```text
HmiDisplayTypography
```

负责。

`HmiTypography` 删除 `clock` / `dashboardValue`，或至少默认引用：

```dart
HmiDisplayTypography.clock
HmiDisplayTypography.dashboardValue
```

不要复制 `120 / 68`。

---

# 13. Small / Medium / Large 的推荐实现

## 13.1 设置模型

```dart
enum AppTextSize {
  small,
  medium,
  large,
}

extension AppTextSizeX on AppTextSize {
  double get scale => switch (this) {
    AppTextSize.small => 0.90,
    AppTextSize.medium => 1.00,
    AppTextSize.large => 1.12,
  };
}
```

---

## 13.2 `CommonSettingsStore`

当前 Store 只有：

```text
language
unit
country
```

建议新增：

```text
textSize
```

JSON：

```json
{
  "language": "en-US",
  "unit": "Metric",
  "country": "US",
  "textSize": "medium"
}
```

旧 JSON 不存在该字段时默认 `medium`，保证兼容。

---

# 14. 根 `MediaQuery` 的实现必须注意当前 `_matchFlutterPiDensity`

当前 `app.dart`：

```text
_appBuilder
  ↓
MediaQuery(alwaysUse24HourFormat)
  ↓
_matchFlutterPiDensity(context, child)
```

而 `_matchFlutterPiDensity()` 内部再次：

```dart
final mq = MediaQuery.of(context);
...
MediaQuery(data: mq.copyWith(...))
```

未来如果直接在外层加入 `textScaler`，容易出现内外 MediaQuery 数据来源不一致。

### 推荐改造

先生成唯一的 `appMediaQuery`：

```dart
final baseMq = MediaQuery.of(context);
final appMq = baseMq.copyWith(
  alwaysUse24HourFormat: _services.wallClock.use24HourFormat,
  textScaler: TextScaler.linear(_commonSettingsStore.textSize.scale),
);
```

然后 `_matchFlutterPiDensity` 改为接收：

```dart
MediaQueryData appMq
```

而不是内部再次 `MediaQuery.of(context)`。

Density 处理只修改：

```text
size
devicePixelRatio
```

必须保留：

```text
textScaler
alwaysUse24HourFormat
```

这样 QEMU / Flutter-pi / 真机三条链路才能使用同一字号设置。

---

# 15. Layout 不建议第一天就做三套完整参数表

先让 100% 固定。

Small / Large 第一版只增加必要的布局补偿：

```text
Settings Row minHeight
Tab minHeight
Dialog maxHeight
Input minHeight
Card vertical padding
```

不要做：

```text
small 全套 UI 常量
medium 全套 UI 常量
large 全套 UI 常量
```

否则维护成本会快速变成三倍。

推荐形式：

```text
100% 基准 Metrics
+ 少量 Size Mode Override
```

例如：

| 参数 | Small | Medium | Large |
|---|---:|---:|---:|
| Text Scale | 0.90 | 1.00 | 1.12 |
| Settings Row minHeight | 0.95× | 1.00× | 1.10× |
| Tab Height | 64 | 68 | 76 |
| Dialog vertical padding | 0.95× | 1.00× | 1.08× |

按钮第一版可以先保持现有高度，重点验证文字是否有足够上下余量；确有问题再增加 Large-only 高度补偿。

---

# 16. Dialog 布局还需要优化固定高度问题

`TipDialogHost.showLightPrompt` 默认：

```text
width  = 700
height = 480~680
```

Engineer Entry 又存在固定计算高度。

未来 Large 字体需要检查：

- Title 是否允许 2 行；
- Body 是否进入滚动；
- Bottom Action 是否固定可见；
- 不应该通过 `FittedBox.scaleDown` 普遍把用户选的大字号重新缩小。

推荐规则：

```text
标题：优先 1 行，英文极端情况允许 2 行
正文：允许滚动
按钮：始终保持可见
Dialog：maxHeight 使用屏幕比例而不是固定 px
```

---

# 17. CI / Lint 建议

完成 100% 收敛后新增规则：

### 禁止业务裸字号

```text
lib/features/**
lib/ui/**
```

禁止：

```dart
fontSize: 22
fontSize: 26
```

允许：

```text
app/theme/**
明确登记的 CustomPainter / Gauge / Chart metrics
```

### 禁止正文由标题动态推导

新增代码禁止调用：

```dart
AppTypography.tipBodySizeForTitle(...)
```

### 手工 TextPainter 检查

凡是布局测量型 `TextPainter`：

```text
必须明确传 TextScaler
```

或明确注释：

```text
// Intentionally fixed-size display chrome; does not follow user text size.
```

避免“忘记缩放”和“故意不缩放”混在一起。

---

# 18. 推荐实施顺序

## P0 — 先冻结 100%

1. 最终确认 Hero：当前包 24；若定稿为 26，则统一改为 26。
2. 新增 `dialogBody / importantDialogBody / dialogOptionLabel` 等语义角色。
3. 迁移 5 个 `tipBodySizeForTitle()` 调用。
4. 清理 13 个生产裸数字字号。
5. 去除 Tab 字号双数据源。
6. 统一 `HmiDisplayTypography` 的 68 / 120 单一数据源。

## P0 — 修复缩放前置问题

7. 修复 `WordBoundaryLabel` / `WordBoundaryBody` 的 TextScaler。
8. 修复 `ProductTopTabs._tabWidthFor()` 的 TextScaler。
9. 修复 `WorkModeStatusBar` 手工测量 TextScaler。
10. 明确 Home Quick Action / Clock / Gauge 的缩放策略。

## P1 — 接入三档字号

11. 增加 `AppTextSize`。
12. 扩展 `CommonSettingsStore`。
13. 设置页增加 Small / Medium / Large。
14. 根 MediaQuery 注入 TextScaler。
15. 重构 `_matchFlutterPiDensity`，保证 scaler 不丢失。

## P1 — UI 适配

16. English-first 检查按钮宽度、Tab、设置行。
17. Dialog 大字号滚动与高度适配。
18. 固定宽按钮组检查英文溢出。
19. Display 类内容进行 clamp。

## P2 — 自动化

20. CI 禁止业务新增裸字号。
21. 增加 English Small / Medium / Large 截图回归。
22. 增加 QEMU + RK3566 真机验收。

---

# 19. 最终建议架构

```text
AppTypography
│
│  基础 100% 字号尺度
│
├───────────────┐
│               │
▼               ▼
HmiTypography   HmiDisplayTypography
│               │
│ 语义 UI       │ 时钟 / Gauge / 大数值
│               │
▼               ▼
Text / Button   Display / Painter
│
▼
MediaQuery.textScaler
0.90 / 1.00 / 1.12
│
▼
Small / Medium / Large
```

布局则保持独立：

```text
HmiButtonMetrics
HmiTabMetrics
HmiLayoutMetrics（后续新增）
```

即：

> **Typography 决定“字是什么层级”，Metrics 决定“容器有多大”，TextScaler 决定“用户选择多大的字”。三者不要互相推导。**

---

# 20. 本次代码审查最重要的优化点

按优先级排序：

1. **`WordBoundaryLabel` 使用 `TextScaler.noScaling` 是三档字号上线前最需要修的隐患。**
2. **`tipBodySizeForTitle()` 应退出业务排版逻辑，正文改成显式语义 Token。**
3. **`ProductTopTabs` / `WorkModeStatusBar` 手工宽度测量需要 TextScaler。**
4. **当前上传包 Hero 仍是 24，与已讨论的 26 基线不一致。**
5. **清理 13 处生产裸字号，可以让 100% 基线真正冻结。**
6. **Tab 字号存在 `HmiTabMetrics` 与 `HmiTypography` 双数据源，应合并。**
7. **Clock / Dashboard 68、120 在 `HmiTypography` 与 `HmiDisplayTypography` 重复，应保留一个 SoT。**
8. **Home Quick Action 当前“自适应 fit 字号”与未来全局 TextScaler 会冲突，需要明确 clamp 策略。**

完成以上项目后，再开发 Small / Medium / Large，整体改动会从“全项目修布局”变成“少量已知组件适配”。
