# FrostUI 100% 字号与布局基线规范

> 审查对象：`lib(1).zip`  
> 目标设备：1280 × 800 工业触控屏  
> 基准字号：100%（后续“中号”）  
> 验收语言：英文优先，中文基础回归  
> 当前阶段：只建立一套稳定的 100% 基线，不实现大、中、小缩放

---

## 1. 目标

当前项目已经把大部分裸数字字号收敛到了 `AppTypography`，但还没有建立“组件类型 → 字号 → 高度 → 宽度策略”的完整关系，导致以下问题：

1. 同一种 `CyberButtonSize.small` 在不同页面使用了不同字号；
2. 按钮宽度由页面随意设置，开发者容易根据宽度临时调整字号；
3. Tab、正文、设置项、卡片、弹窗等虽然引用了统一数字，但缺少明确的语义角色；
4. `HmiTypography` 已经存在，但业务页面基本没有使用，规范无法由组件强制执行；
5. 后续直接增加“大、中、小”会把现有不一致同步放大。

本阶段应先完成：

> **将当前 100% 字号定义为唯一标准基线，使同一组件规格拥有固定字号、高度、内边距和宽度规则。**

100% 基线稳定后，再将它定义为字体设置中的“中号”。

---

## 2. `lib` 现状审查

### 2.1 已完成的部分

项目当前共有约 351 个 Dart 文件，其中生产代码约 341 个。生产代码中已经基本不存在直接填写数字的：

```dart
fontSize: 21
```

当前字号主要集中在：

```text
lib/app/theme/app_typography.dart
lib/app/theme/hmi_typography.dart
lib/app/theme/hmi_display_typography.dart
```

`AppTypography` 已建立以下基础字号阶梯：

```text
12 / 14 / 16 / 18 / 20 / 22 / 24 / 28 / 32 / 36 / 44 / 52
```

大型展示字号单独保留：

```text
68  — 仪表盘大型数值
120 — 首页时钟
```

这说明项目已经完成了“数字收口”，但还没有完成“语义和组件收口”。

### 2.2 当前字号仍以数字 Token 方式使用

生产代码中约有 222 处直接引用：

```dart
fontSize: AppTypography.controlSize
fontSize: AppTypography.navigationSize
fontSize: AppTypography.sectionTitleSize
```

其中主要使用量为：


| 基础 Token          | 生产代码使用量 | 当前典型用途           |
| ----------------- | ------- | ---------------- |
| `control` 20      | 40      | 设置项、按钮、标签、表单     |
| `sectionTitle` 22 | 31      | 卡片标题、操作按钮、告警条目   |
| `body` 18         | 29      | 正文、选择项、输入内容      |
| `supporting` 16   | 25      | 副标题、单位、帮助信息      |
| `navigation` 24   | 20      | 顶部 Tab、部分按钮、侧边操作 |
| `pageTitle` 28    | 15      | 页面或监控区标题、告警按钮    |


问题在于：

```text
navigation = 24
```

既被用于顶部 Tab，也被用于普通按钮；

```text
sectionTitle = 22
```

既被用于卡片标题，也被用于设备操作按钮；

因此它们目前只是“字号数字的别名”，还没有形成稳定的组件语义。

### 2.3 `HmiTypography` 已定义但基本未使用

项目已经定义：

```dart
HmiTypography.cardTitle
HmiTypography.metricLabel
HmiTypography.metricValue
HmiTypography.button
HmiTypography.navigation
HmiTypography.body
```

但业务页面仍主要直接使用：

```dart
AppTypography.xxxSize
```

`ThemeData.textTheme` 的实际引用也很少。

因此当前结构是：

```text
AppTypography 数字统一了
            ↓
业务页面仍能自由选择任意 Token
            ↓
同类组件依然可能使用不同字号
```

后续应改为：

```text
AppTypography 定义基础字号阶梯
            ↓
HmiTypography 定义组件语义角色
            ↓
公共组件固定读取对应语义角色
            ↓
业务页面只选择组件规格，不选择字号
```



### 2.4 按钮是当前最明显的不一致来源

生产代码中约有 51 处 `CyberButton`：


| CyberButton 规格 | 数量  |
| -------------- | --- |
| 未指定，依赖默认规格     | 31  |
| `small`        | 18  |
| `mini`         | 1   |
| `medium`       | 1   |


同样是 `small`，当前存在以下字号差异：


| 场景                           | 当前字号           |
| ---------------------------- | -------------- |
| Quick Mode `More status`     | 12             |
| Laser Enable 提示确认            | 14             |
| 普通小按钮                        | 继承 CyberUI 默认值 |
| Live Machine Status `Got it` | 20             |
| AI Vision 选择按钮               | 24             |
| 工艺库 Reset / Favorite         | 24             |


这说明当前按钮规格只控制了部分高度和外观，**没有控制按钮文字**。

此外，按钮宽度当前包括：

```text
内容自适应
168 固定宽度
280 固定宽度
340 固定宽度
占满父容器
```

宽度不同本身没有问题。真正的问题是：

> 页面根据宽度或文案长度自行决定字号，而不是由按钮规格决定字号。



### 2.5 Tab 当前存在两种有效层级

当前主要 Tab：


| Tab 类型                    | 高度  | 图标  | 字号  |
| ------------------------- | --- | --- | --- |
| Settings / Monitor 顶部 Tab | 68  | 31  | 24  |
| Engineer Process 五项 Tab   | 68  | 31  | 20  |


这两组不必强行统一为同一字号，因为其信息密度不同：

- Settings / Monitor 属于应用一级导航；
- Engineer Process 一行包含五项，属于高密度业务模式导航。

需要做的是为它们定义两个明确角色，而不是继续使用模糊的 `navigationSize` 和 `controlSize`。

### 2.6 当前设置页布局关系基本合理

`SettingsDimens` 当前关系：


| 元素        | 当前值 |
| --------- | --- |
| 页面左右边距    | 24  |
| 卡片间距      | 24  |
| 设置行最小高度   | 70  |
| 设置行水平内边距  | 20  |
| 设置行垂直内边距  | 8   |
| 设置项标题     | 20  |
| 设置项副标题    | 16  |
| 顶部 Tab 高度 | 68  |
| 顶部 Tab 字号 | 24  |


这一组可以作为 100% 设置页面的基础，不需要整体推翻。主要需要修正：

- 使用语义样式替代数字字号；
- 设置行使用 `minHeight`，不能固定死高度；
- 标题和副标题的最大行数统一；
- 设置页按钮按按钮规格重做。

---



## 3. 100% 基线的核心规则



### 3.1 100% 的定义

100% 是项目所有字体和 UI 尺寸的设计原点：

```text
TextScaler = 1.0
1280 × 800 设计画布
英文界面作为严格布局基准
```

后续设置中的：

```text
Small  → 从 100% 基线缩小
Medium → 100% 基线
Large  → 从 100% 基线放大
```

当前阶段不要先引入 `0.90 / 1.00 / 1.12`，否则会掩盖基础组件本身的不一致。

### 3.2 字号由语义角色决定

错误方式：

```dart
TextStyle(fontSize: AppTypography.navigationSize)
```

页面可以把导航字号用于任何文字。

正确方式：

```dart
context.hmiTypography.primaryTabLabel
context.hmiTypography.buttonMedium
context.hmiTypography.settingsRowTitle
```

页面只能表达“它是什么”，不能直接决定“它多大”。

### 3.3 按钮宽度不决定字号

同一规格按钮应满足：

```text
相同高度
相同字号
相同字重
相同水平内边距
相同最小宽度
```

但允许宽度不同：

```text
Save             → 较短
Save changes     → 较长
Restore defaults → 更长
```

字号始终保持一致。英文放不下时，处理顺序必须是：

```text
1. 增加按钮宽度
2. 改为按钮组等宽或全宽
3. 缩短英文文案
4. 调整按钮组排列方式
5. 不允许局部缩小字号
```



### 3.4 组件拥有文字样式

业务页面不再写：

```dart
CyberButton(
  child: Text(
    label,
    style: const TextStyle(fontSize: 24),
  ),
)
```

应由按钮组件内部统一应用样式：

```dart
HmiButton(
  label: label,
  size: HmiButtonSize.large,
)
```

Tab、设置行、卡片标题、弹窗标题也采用同样原则。

---



## 4. 100% 基础字号阶梯

保留当前 `AppTypography` 的基础数字阶梯，不立即修改基础数值：


| 基础字号               | 字号  | 字重  | 行高   | 仅用于定义语义角色    |
| ------------------ | --- | --- | ---- | ------------ |
| `micro`            | 12  | 400 | 1.25 | 技术刻度、极次要信息   |
| `caption`          | 14  | 400 | 1.30 | 辅助标签、单位、时间   |
| `supporting`       | 16  | 400 | 1.35 | 副标题、帮助、说明    |
| `body`             | 18  | 400 | 1.35 | 普通正文、列表内容    |
| `control`          | 20  | 500 | 1.20 | 设置项、输入值、普通控件 |
| `sectionTitle`     | 22  | 500 | 1.20 | 卡片标题、分组标题    |
| `navigation`       | 24  | 500 | 1.10 | 一级导航         |
| `pageTitle`        | 28  | 500 | 1.15 | 页面标题、重要区域标题  |
| `dialogTitle`      | 32  | 600 | 1.15 | 普通弹窗标题       |
| `largeDialogTitle` | 36  | 600 | 1.10 | 重要弹窗标题       |
| `display`          | 44  | 600 | 1.05 | 大型操作或展示标题    |
| `criticalTitle`    | 52  | 700 | 1.05 | 严重告警标题       |
| `metricValue`      | 28  | 500 | 1.00 | 常规仪表数值       |


专用展示字号继续保留：


| 专用角色    | 字号  |
| ------- | --- |
| 仪表盘大型数值 | 68  |
| 首页时钟    | 120 |


基础阶梯不应直接暴露给业务页面。业务页面应使用下一节的组件语义角色。

---



## 5. 100% 组件语义字号



### 5.1 页面与正文


| 语义角色               | 100% 字号 | 字重  | 使用范围               |
| ------------------ | ------- | --- | ------------------ |
| `pageTitle`        | 28      | 500 | 页面主标题、Monitor 大区标题 |
| `sectionTitle`     | 22      | 500 | 卡片标题、内容分组标题        |
| `settingsRowTitle` | 20      | 500 | 设置项名称              |
| `settingsRowValue` | 20      | 500 | 设置项右侧值、输入值         |
| `body`             | 18      | 400 | 普通正文、列表正文          |
| `supporting`       | 16      | 400 | 设置项副标题、帮助说明        |
| `caption`          | 14      | 400 | 单位、时间、次要状态         |
| `technicalMeta`    | 12      | 400 | 图表刻度、调试型元数据        |




### 5.2 数据和状态


| 语义角色              | 100% 字号 | 字重      | 使用范围             |
| ----------------- | ------- | ------- | ---------------- |
| `metricLabel`     | 20      | 400/500 | 温度、压力、通信状态名称     |
| `metricValue`     | 28      | 500     | 普通监控数值           |
| `metricUnit`      | 16      | 400     | 数值单位             |
| `dashboardValue`  | 68      | 500     | Quick Mode 中央大数值 |
| `clock`           | 120     | 500     | 首页时钟             |
| `statusBarLabel`  | 20      | 500     | 状态栏普通状态          |
| `statusBarAction` | 24      | 500     | Home 等主要状态栏操作    |


数值继续使用：

```dart
FontFeature.tabularFigures()
```

避免实时数据变化时宽度跳动。

### 5.3 弹窗


| 弹窗等级 | 标题  | 正文    | 操作按钮      |
| ---- | --- | ----- | --------- |
| 普通提示 | 32  | 18    | Medium 18 |
| 重要确认 | 36  | 20/22 | Large 20  |
| 严重告警 | 52  | 28/32 | Hero 24   |


不得把普通成功提示的正文设置为 32 或 36。大字号正文只允许用于需要远距离读取的安全告警。

当前建议重点修正：

- `custom_home_save_success_dialog.dart`：普通成功提示正文不应继续使用 32；
- `operation_failed_dialog.dart`：普通错误正文不应直接使用 32；
- `engineer_mode_entry_tips_dialog.dart`：若属于强安全提示，可以保留 Critical 等级；
- `warn_dialog_body.dart`：保留严重告警专用等级，不与普通弹窗共用。

---



## 6. 按钮 100% 规格



### 6.1 标准按钮规格


| 规格       | 视觉高度 | 文字字号 | 字重      | 最小宽度 | 水平内边距 | 图标  |
| -------- | ---- | ---- | ------- | ---- | ----- | --- |
| `mini`   | 36   | 14   | 600     | 72   | 12    | 18  |
| `small`  | 44   | 16   | 600     | 96   | 16    | 20  |
| `medium` | 52   | 18   | 600     | 120  | 24    | 24  |
| `large`  | 60   | 20   | 600     | 144  | 28    | 28  |
| `hero`   | 72   | 24   | 600/700 | 200  | 32    | 32  |


说明：

- `mini` 只用于卡片内部、表单尾部等紧凑操作；其实际触摸区域不得小于 44；
- 普通弹窗默认使用 `medium`；
- 页面底部主要操作使用 `large`；
- 严重告警和关键流程才使用 `hero`；
- Quick Mode 的大型激光按钮属于特殊业务组件，继续使用 44，不纳入普通按钮规格。



### 6.2 宽度策略

为按钮增加独立的布局策略：

```dart
enum HmiButtonWidthPolicy {
  adaptive, // 根据文案宽度增长
  equal,    // 同一按钮组等宽
  fixed,    // 业务明确要求固定宽度
  fill,     // 占满父容器
}
```

使用规则：


| 场景                        | 宽度策略                |
| ------------------------- | ------------------- |
| 单独的普通操作                   | `adaptive`          |
| 弹窗 Cancel / Confirm       | `equal`             |
| 设计明确的 168 / 280 / 340 宽按钮 | `fixed`             |
| 登录、保存整页配置、底部主操作           | `fill` 或大固定宽度       |
| 工具栏中的连续按钮                 | `equal` 或统一 `fixed` |




### 6.3 相同高度但宽度不同如何处理

相同规格按钮可以左右长度不同，例如：

```text
[ Save ]
[ Save changes ]
[ Restore defaults ]
```

三者只要都属于 `large`，就必须统一：

```text
高度 60
字号 20
字重 600
水平内边距 28
```

最终宽度由文案长度和宽度策略决定。不能因为按钮较窄就改成 16，也不能因为按钮较宽就改成 24。

### 6.4 当前项目按钮映射建议


| 当前场景                             | 当前问题             | 100% 目标规格               |
| -------------------------------- | ---------------- | ----------------------- |
| Advanced 自动归零                    | `mini`，用途正确      | `mini / 14`             |
| 弹窗 Cancel / Confirm，宽 168        | 字号依赖默认值          | `medium / 18 / equal`   |
| Device Info `Check update`，宽 340 | 当前 `small`       | `large / 20 / fixed`    |
| Custom Home `Save changes`，宽 340 | 当前 `small`       | `large / 20 / fixed`    |
| AI Vision 选择按钮                   | `small` 却使用 24   | `large / 20 / fill`     |
| 工艺库 Reset / Save favorite        | `small` 却使用 24   | `large / 20`            |
| Quick Mode `More status`         | `small` 却使用 12   | `small / 16`            |
| Laser Enable 提示确认                | `small` 却使用 14   | `medium / 18`           |
| Live Status `Got it`，宽 280       | `small` 却使用 20   | `medium / 18 / fixed`   |
| 普通系统提示 Close / OK                | 依赖默认 CyberButton | `medium / 18`           |
| 严重告警确认                           | 当前可达到 28         | `hero / 24`             |
| Process Mode Outline 操作          | 业务专用 22          | 保留 `processAction / 22` |
| Quick Laser 主操作                  | 业务专用 44          | 保留 `displayAction / 44` |


---



## 7. Tab 100% 规格



### 7.1 Tab 层级


| Tab 类型         | 高度  | 字号  | 图标    | 使用范围                  |
| -------------- | --- | --- | ----- | --------------------- |
| `primaryTab`   | 68  | 24  | 31    | Settings、Monitor 一级导航 |
| `processTab`   | 68  | 20  | 31    | Engineer 五项工艺模式       |
| `secondaryTab` | 48  | 18  | 20–24 | 页面内部二级切换              |
| `compactTab`   | 40  | 16  | 可选    | 小型筛选、紧凑分类             |




### 7.2 当前顶部 Tab 处理

以下当前值可保留：

```text
SettingsTopTabs：68 / 24 / icon 31
ProductTopTabs：68 / 24 / icon 31
EngineerProcessTabBar：68 / 20 / icon 31
```

但代码中应替换为明确语义：

```dart
context.hmiTypography.primaryTabLabel
context.hmiTypography.processTabLabel
```

而不是：

```dart
AppTypography.navigationSize
AppTypography.controlSize
```



### 7.3 Tab 宽度规则

一级 Tab：

- 英文优先；
- 单行显示；
- 根据英文测量结果增加宽度；
- 一屏放不下时横向滚动；
- 不通过缩小字号解决；
- 不对一级导航使用省略号作为常规方案。

当前 `ProductTopTabs` 已经按照文字测量动态计算宽度，这一思路应保留并推广。

Engineer 五项 Tab：

- 保留固定权重；
- 使用 20 号字体；
- 英文标签必须在 1280 宽度内进行专项验收；
- 若个别英文仍超长，优先优化 ARB 文案，而不是降低该 Tab 的字号。

---



## 8. 设置页面 100% 布局



### 8.1 基线参数


| 参数       | 100% 基线  |
| -------- | -------- |
| 页面边距     | 24       |
| 卡片间距     | 24       |
| 设置行最小高度  | 70       |
| 设置行水平内边距 | 20       |
| 设置行垂直内边距 | 8        |
| 标题和副标题间距 | 4        |
| 标题       | 20 / 500 |
| 副标题      | 16 / 400 |
| 右侧值      | 20 / 500 |
| 帮助说明     | 16 / 400 |
| 顶部一级 Tab | 68 / 24  |




### 8.2 高度必须是最小高度

保留：

```dart
ConstrainedBox(
  constraints: const BoxConstraints(
    minHeight: SettingsDimens.rowMinHeight,
  ),
)
```

禁止改成：

```dart
SizedBox(height: 70)
```

英文副标题可能占两行，因此设置行需要允许自然增高。

### 8.3 文本行数


| 位置     | 最大行数      |
| ------ | --------- |
| 设置项标题  | 1，必要时 2   |
| 设置项副标题 | 2         |
| 设置项右侧值 | 1         |
| 帮助说明   | 不固定，随区域滚动 |
| 一级 Tab | 1         |


主要设置项标题不能使用 `FittedBox` 自动缩小。

---



## 9. Monitor 和卡片布局

当前 Monitor 基线可保留：


| 元素           | 100% 字号 |
| ------------ | ------- |
| Monitor 区域标题 | 28      |
| Metric Label | 20      |
| Metric Value | 28      |
| 单位           | 16      |
| 普通卡片标题       | 22      |
| 普通正文         | 18      |


统计卡片统一结构：

```text
卡片标题 22
主数值 28 或 68
单位 16
补充说明 14 或 16
```

同一行卡片不得根据文字长度单独缩小标题字号。英文超长时允许：

- 标题两行；
- 增加卡片宽度；
- 减少装饰性间距；
- 优化英文文案。

---



## 10. 推荐代码结构



### 10.1 `AppTypography` 只保留基础阶梯

`AppTypography` 继续负责数字和基础字重，不直接代表具体 UI 组件。

### 10.2 扩展 `HmiTypography`

建议增加：

```dart
@immutable
class HmiTypography extends ThemeExtension<HmiTypography> {
  const HmiTypography({
    // Page and content
    required this.pageTitle,
    required this.sectionTitle,
    required this.settingsRowTitle,
    required this.settingsRowValue,
    required this.body,
    required this.supporting,
    required this.caption,

    // Tabs
    required this.primaryTabLabel,
    required this.processTabLabel,
    required this.secondaryTabLabel,
    required this.compactTabLabel,

    // Buttons
    required this.buttonMini,
    required this.buttonSmall,
    required this.buttonMedium,
    required this.buttonLarge,
    required this.buttonHero,
    required this.processAction,

    // Data
    required this.metricLabel,
    required this.metricValue,
    required this.metricUnit,

    // Dialogs
    required this.dialogTitle,
    required this.importantDialogTitle,
    required this.criticalTitle,
    required this.criticalBody,
  });
}
```

100% 默认映射：

```dart
buttonMini: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
buttonSmall: AppTypography.supporting.copyWith(fontWeight: FontWeight.w600),
buttonMedium: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
buttonLarge: AppTypography.control.copyWith(fontWeight: FontWeight.w600),
buttonHero: AppTypography.navigation.copyWith(fontWeight: FontWeight.w700),

primaryTabLabel: AppTypography.navigation,
processTabLabel: AppTypography.control,
secondaryTabLabel: AppTypography.body,
compactTabLabel: AppTypography.supporting,
```



### 10.3 新增按钮规格 Token

建议新增：

```text
lib/app/theme/hmi_button_metrics.dart
```

```dart
enum HmiButtonSize {
  mini,
  small,
  medium,
  large,
  hero,
}

@immutable
class HmiButtonMetrics {
  const HmiButtonMetrics({
    required this.height,
    required this.minWidth,
    required this.horizontalPadding,
    required this.iconSize,
    required this.textStyle,
  });

  final double height;
  final double minWidth;
  final double horizontalPadding;
  final double iconSize;
  final TextStyle textStyle;
}
```



### 10.4 建立项目级 `HmiButton`

按钮最好接受 `label`，不要让页面直接传入任意样式的 `Text`：

```dart
HmiButton(
  label: l10n.saveChanges,
  size: HmiButtonSize.large,
  widthPolicy: HmiButtonWidthPolicy.fixed,
  width: 340,
  variant: HmiButtonVariant.primary,
  onPressed: onSave,
)
```

组件内部统一：

- 高度；
- 最小宽度；
- 水平内边距；
- 字号和字重；
- 图标尺寸；
- 单行规则；
- 禁用状态；
- 点击声效。

迁移完成后，业务页面原则上不再直接创建 `CyberButton`。

---



## 11. 迁移顺序



### 第一阶段：建立规范组件

1. 扩展 `HmiTypography`；
2. 新增 `HmiButtonMetrics`；
3. 新增 `HmiButton`；
4. 新增 Tab 语义样式；
5. 保持 100% 比例，不接入字体缩放。



### 第二阶段：先迁移全局公共组件

优先顺序：

```text
SettingsTopTabs
ProductTopTabs
EngineerProcessTabBar
SettingsSwitchRow
SettingsControlRow
SettingsSliderRow
SettingsOptionTile
MonitorSectionHeader
普通 Dialog Action Row
```

这些组件迁移后会一次影响大量页面。

### 第三阶段：统一按钮

按优先级处理：

```text
1. 普通弹窗按钮
2. Settings 页面主按钮
3. Monitor 页面按钮
4. Process Library 按钮
5. Quick / Engineer 特殊按钮
6. 严重告警按钮
```



### 第四阶段：清理业务页面字号选择

业务页面禁止继续使用：

```dart
fontSize: AppTypography.xxxSize
```

改为：

```dart
style: context.hmiTypography.xxx
```

只有以下目录允许直接引用基础数字：

```text
lib/app/theme/
明确的 CustomPainter / TextPainter 适配层
首页时钟和大型仪表等专用展示组件
```

---



## 12. CI 约束

100% 迁移完成后，CI 应检查：

### 12.1 禁止业务裸字号

```bash
rg -n "fontSize\s*:" lib/features lib/ui \
  --glob '!**/demo/**' \
  --glob '!**/theme/**'
```

后续应进一步禁止业务页面直接引用 `AppTypography.*Size`。

### 12.2 禁止业务页面自定义按钮字号

检查：

```text
CyberButton + TextStyle(fontSize: ...)
HmiButton 内部以外直接使用 CyberButton
```

目标是：

```text
业务代码选择 HmiButtonSize
公共组件决定字号
```



### 12.3 禁止主要按钮省略号

主要操作按钮不得使用：

```dart
TextOverflow.ellipsis
```

英文放不下必须调整布局或文案。

---



## 13. 100% 验收清单



### 13.1 英文严格验收

重点检查项目中已有的长英文：

```text
Save changes
Restore defaults
Save as favorite
Open Wi-Fi settings
Forget network
Apply to device
Confirm replacement
Continuous welding
Weld seam cleaning
Device information
Custom home
```

验收标准：

- 一级 Tab 不截断；
- 主要按钮不显示省略号；
- 同规格按钮字号完全一致；
- 同按钮组高度和宽度规则一致；
- 设置项标题和副标题不重叠；
- 卡片标题不因英文变长而单独缩小；
- 普通弹窗正文不使用过大的展示字号；
- QEMU 与 RK3566 真机视觉一致。



### 13.2 组件一致性验收

每种按钮建立一张测试页，统一展示：

```text
Mini   : Add / Auto
Small  : Retry / More status
Medium : Cancel / Confirm / Got it
Large  : Check update / Save changes / Restore defaults
Hero   : Emergency stop confirmation
```

每种 Tab 建立测试：

```text
Primary tab
Process tab
Secondary tab
Compact tab
```



### 13.3 截图基线

至少建立以下 100% 英文截图：

```text
Settings - Device information
Settings - General
Settings - Advanced
Settings - Custom home
Monitor
Quick mode
Engineer mode
Normal dialog
Critical alarm dialog
```

这些截图将作为未来 Small / Medium / Large 的比较基线。

---



## 14. 最终标准

100% 版本完成后，项目应形成以下关系：

```text
AppTypography
└── 只定义基础字号阶梯

HmiTypography
└── 定义页面、正文、Tab、按钮、弹窗、数值等语义样式

HmiButtonMetrics
└── 定义按钮高度、最小宽度、内边距和图标尺寸

HmiButton
└── 根据按钮规格自动使用对应字号和布局

公共 Tab / Settings / Dialog 组件
└── 固定读取语义样式，业务页面不能自由指定字号
```

核心规则：

> **同一按钮规格必须使用同一字号；按钮宽度可以随英文文案变化，但字号不能随宽度变化。**

> **Tab、正文、设置项、卡片和弹窗必须按语义角色选字号，而不是按页面视觉临时选择数字。**

> **当前先冻结并验收 100% 基线，后续字体设置中的“中号”直接等于该基线。**

