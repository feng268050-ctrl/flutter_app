# FrostUI 文案与字号统一方案（英文优先）

## 1. 目标

对现有 Flutter HMI 项目中的文案、字号、字重、行高和文字容器进行统一治理，解决以下问题：

- 字号大小不一，散落在页面和组件中；
- 同一语义使用不同字号，相同字号承担不同语义；
- 设置页、监控页、状态栏、告警弹窗等模块各自维护字号常量；
- 英文文案较长，容易出现截断、溢出、布局跳动；
- 依赖 `FittedBox`、省略号或临时缩小字号解决空间问题，缺乏统一规则；
- 后续修改整体字号时，需要逐个页面查找和调整。

本次方案以**英文界面作为主要设计与验收基准**。中文界面只要求功能完整、无严重溢出和遮挡，不要求每一处视觉占位与英文完全一致。

---

## 2. 项目现状

对 `lib.zip` 进行静态扫描后，得到以下结果：

| 项目 | 数量 |
|---|---:|
| Dart 文件 | 347 |
| `fontSize:` 使用位置 | 251 |
| 直接使用数字字号 | 159 |
| 直接数字字号种类 | 21 |
| 排除 Demo 和本地化生成代码后的 `fontSize:` | 204 |
| 生产代码中的直接数字字号 | 112 |
| 英文/中文本地化键 | 634 |

生产代码中的硬编码字号主要集中在：

| 模块 | 硬编码字号数量 |
|---|---:|
| `process_mode` | 37 |
| `settings` | 26 |
| `monitor` | 25 |
| `process_library` | 7 |
| `safety_tips` | 5 |
| 其他模块 | 12 |

项目中已存在部分模块级字号配置：

- `SettingsDimens`
- `MonitorDimens`
- `WorkModeStatusBarDimens`
- `WarnDialogMetrics`
- `ProcessModeDimens`
- `QuickModePickerDimens`

这些配置减轻了部分硬编码问题，但仍属于模块内部约定，尚未形成项目级 Typography 体系。

项目部分页面以 `1280 × 800` 为设计基准。当前已经使用 `LayoutBuilder`、`FittedBox`、`TextOverflow.ellipsis` 和动态缩放，但使用方式不统一。

---

## 3. 英文优先原则

### 3.1 英文决定容器尺寸

按钮、Tab、卡片标题、设置项和弹窗等组件，应首先使用英文文案验证宽度和高度。

设计流程调整为：

1. 使用英文最长文案确定组件最小宽度和最大行数；
2. 完成英文页面布局；
3. 切换中文进行基础回归；
4. 中文存在较多留白可以接受，但不能溢出、遮挡或不可点击。

不要先按照较短的中文文案确定组件宽度，再通过缩小英文字号补救。

### 3.2 中英文默认使用同一字号

默认情况下，中英文使用同一个 Typography Token：

```dart
Text(
  context.l10n.saveChanges,
  style: context.hmiTypography.button,
)
```

不建议采用以下做法：

```dart
fontSize: isEnglish ? 18 : 22
```

不同语言使用不同字号会导致：

- 页面层级不一致；
- 切换语言时布局跳动；
- 组件规则逐渐失控；
- 后续维护成本增加。

只有极少数经过产品确认的品牌标题或特殊展示文字，才允许设置语言差异，并需要进入白名单。

### 3.3 英文过长时优先调整布局

处理顺序应为：

1. 增加可用宽度；
2. 减少无意义的左右留白；
3. 使用 `Expanded` 或 `Flexible`；
4. 允许合理换行；
5. 缩短英文文案；
6. 非关键信息使用省略号；
7. 最后才考虑小范围缩小字号。

普通正文、告警说明和安全提示不得依赖 `FittedBox` 强行缩小。

### 3.4 英文采用 PascalCase

除品牌缩写、协议名称和单位外，英文界面**命名类**文案（按钮、标签、分区标题、枚举名）统一使用 PascalCase（各实词首字母大写）：

```text
推荐：Selected On Home
不推荐：SELECTED ON HOME
不推荐：Selected on home
```

全大写英文更宽、识别速度更慢，也会增加窄容器中的溢出风险。视觉层级应通过字号、字重、颜色和间距表达，而不是依赖全大写。完整说明句、帮助正文仍用正常英文句式（Sentence case），不强制 PascalCase。

---

## 4. 统一字号体系

建议建立项目级语义化字号，而不是继续使用 `font20`、`font24` 等数字名称。

### 4.1 基础字号

| Token | 字号 | 字重 | 行高 | 主要用途 |
|---|---:|---:|---:|---|
| `micro` | 12 | 400 | 1.25 | 图表刻度、调试编号、极次要元数据 |
| `caption` | 14 | 400 | 1.30 | 单位、时间、辅助提示 |
| `supporting` | 16 | 400 | 1.35 | 副标题、帮助说明、表格次要内容 |
| `body` | 18 | 400 | 1.35 | 正文、普通列表内容 |
| `control` | 20 | 500 | 1.20 | 设置项标题、输入内容、普通按钮 |
| `sectionTitle` | 22 | 500 | 1.20 | 卡片标题、分组标题 |
| `navigation` | 24 | 500 | 1.10 | 顶部 Tab、主要导航 |
| `pageTitle` | 28 | 500 | 1.15 | 页面标题、重要指标 |
| `dialogTitle` | 32 | 600 | 1.15 | 普通弹窗标题 |
| `largeDialogTitle` | 36 | 600 | 1.10 | 安全确认、重要提示标题 |
| `display` | 44 | 600 | 1.05 | 大型状态和引导文字 |
| `criticalTitle` | 52 | 700 | 1.05 | 严重告警标题 |

### 4.2 业务专用字号

以下字号不强制并入通用层级：

- 首页时钟；
- 仪表盘中心数值；
- 大型进度数字；
- 工艺模式转轮选中值；
- 图表坐标刻度；
- 特殊设备状态显示。

业务专用字号仍须集中定义，例如：

```dart
abstract final class HmiDisplayTypography {
  static const clock = TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const dashboardValue = TextStyle(
    fontSize: 68,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
```

### 4.3 零散字号归并规则

| 现有字号 | 建议归并 |
|---|---|
| 10、12、13 | `micro` 或 `caption` |
| 14、15 | `caption` 或 `supporting` |
| 16、17 | `supporting` |
| 18 | `body` |
| 20、21 | `control` |
| 22 | `sectionTitle` |
| 24、26、27 | `navigation` 或 `pageTitle`，根据语义判断 |
| 28、29 | `pageTitle` |
| 32、33 | `dialogTitle` |
| 35、37 | `largeDialogTitle` |
| 44、45 | `display` |
| 53 | `criticalTitle` |

归并时必须根据文字角色判断，不能仅按数字接近程度批量替换。

---

## 5. 现有模块映射建议

### 5.1 Settings

| 现有配置 | 新 Token |
|---|---|
| `SettingsDimens.titleSize` | `control` |
| `SettingsDimens.subtitleSize` | `supporting` |
| `advancedTitleSize` | `sectionTitle` |
| `advancedValueSize` | `sectionTitle` 或专用 `settingValue` |
| `advancedSwitchTitleSize` | `navigation` 或 `sectionTitle` |
| `advancedSwitchSubtitleSize` | `control` |
| `SettingsTopTabs.labelSize` | `navigation` |

设置项必须采用“左侧文案自适应、右侧控件固定”的布局：

```dart
Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: typography.control),
          if (subtitle != null)
            Text(
              subtitle!,
              style: typography.supporting,
              maxLines: 3,
            ),
        ],
      ),
    ),
    const SizedBox(width: 24),
    SizedBox(
      width: controlWidth,
      child: trailing,
    ),
  ],
)
```

英文副标题允许比中文多占一行，但不能挤压右侧 Switch、输入框或下拉框。

### 5.2 Monitor

| 现有配置 | 新 Token |
|---|---|
| `MonitorDimens.sectionTitleSize` | `pageTitle` |
| `MonitorDimens.metricLabelSize` | `control` |
| `MonitorDimens.metricValueSize` | `pageTitle` 或专用 `metricValue` |

指标卡片建议采用：

- 英文标题最多 2 行；
- 数值区域高度固定；
- 单位与数值分开；
- 数值使用等宽数字；
- 标题过长时不缩小数值字号；
- 卡片高度按照英文两行标题预留。

### 5.3 顶部状态栏和 Tab

当前选中态与未选中态存在不同字号的情况，例如 `24` 和 `27`。建议统一字号，选中状态通过以下属性区分：

- 字重；
- 文字颜色；
- 背景高亮；
- 下划线或指示条；
- 图标透明度。

不要通过增大选中字号区分状态，否则切换时会产生宽度变化和布局跳动。

### 5.4 Warn / Safety Dialog

| 现有配置 | 新 Token |
|---|---|
| 标题 `53` | `criticalTitle` 52 |
| 正文 `37` | 特殊大正文，建议逐步评估降至 32～36 |
| 确认按钮 `29` | `pageTitle` 28 |
| 普通状态弹窗标题 `32/37` | `dialogTitle` 或 `largeDialogTitle` |
| 普通状态弹窗正文 `20/33` | `control` 或专用 `dialogBodyLarge` |

告警正文和安全说明不得使用省略号。内容超过可视区域时，应使用滚动容器。

---

## 6. 英文文案的组件规则

### 6.1 顶部 Tab

- 默认单行；
- 按英文最长 Tab 计算宽度；
- 同组 Tab 使用相同高度和字号；
- 不允许通过缩小某一个英文 Tab 的字号适配；
- 空间不足时优先使用可滚动 Tab 或重新分组；
- 省略号只能作为极端分辨率的兜底。

### 6.2 按钮

- 主按钮优先保持单行；
- 根据英文文案设置 `minWidth`，不要固定所有按钮为过窄宽度；
- 左右内边距保持一致；
- 图标和文案之间保持固定间距；
- “Save Changes”“Restore Defaults”等英文应作为验收样例；
- 不能通过全大写提升按钮层级。

### 6.3 卡片标题

- 英文允许最多 2 行；
- 中文通常保持 1 行，但不是强制；
- 标题区域预留固定的两行高度；
- 卡片数值或操作按钮的位置不随标题行数上下跳动；
- 非关键卡片可使用省略号；
- 关键状态卡片不能仅依靠省略号，应支持 Tooltip 或详情页。

### 6.4 设置项

- 标题最多 2 行；
- 副标题最多 3 行；
- 右侧控件不得被英文挤压；
- 设置项整体高度可随英文副标题增加；
- 同一组设置项不要求绝对等高，但间距和对齐必须统一。

### 6.5 表格和列表

- 列宽由英文表头和典型英文数据共同确定；
- 表头最多 2 行；
- 非关键单元格可以省略；
- 重要值、设备编号和错误码必须完整显示；
- 数值列右对齐，并使用等宽数字。

### 6.6 弹窗

- 标题允许最多 2 行；
- 正文区域可滚动；
- 英文按钮按最长操作文案确定宽度；
- 按钮过多时改为纵向排列或减少操作数量；
- 安全提示不得因英文变长而缩小到难以阅读。

---

## 7. 代码架构

建议新增：

```text
lib/app/theme/
├── app_theme.dart
├── app_typography.dart
├── hmi_typography.dart
└── typography_tokens.dart
```

### 7.1 通用 Typography

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const micro = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  static const caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.30,
  );

  static const supporting = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const body = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const control = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.20,
  );

  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.20,
  );

  static const navigation = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.10,
  );

  static const pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.15,
  );

  static const dialogTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static const largeDialogTitle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.10,
  );

  static const criticalTitle = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    height: 1.05,
  );

  static const metricValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
```

### 7.2 ThemeExtension

项目专用角色通过 `ThemeExtension` 暴露，避免页面直接依赖常量文件：

```dart
@immutable
class HmiTypography extends ThemeExtension<HmiTypography> {
  const HmiTypography({
    this.cardTitle = AppTypography.sectionTitle,
    this.metricLabel = AppTypography.control,
    this.metricValue = AppTypography.metricValue,
    this.button = AppTypography.control,
    this.alarmTitle = AppTypography.criticalTitle,
  });

  final TextStyle cardTitle;
  final TextStyle metricLabel;
  final TextStyle metricValue;
  final TextStyle button;
  final TextStyle alarmTitle;

  @override
  HmiTypography copyWith({
    TextStyle? cardTitle,
    TextStyle? metricLabel,
    TextStyle? metricValue,
    TextStyle? button,
    TextStyle? alarmTitle,
  }) {
    return HmiTypography(
      cardTitle: cardTitle ?? this.cardTitle,
      metricLabel: metricLabel ?? this.metricLabel,
      metricValue: metricValue ?? this.metricValue,
      button: button ?? this.button,
      alarmTitle: alarmTitle ?? this.alarmTitle,
    );
  }

  @override
  HmiTypography lerp(HmiTypography? other, double t) {
    if (other == null) return this;
    return HmiTypography(
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      metricLabel: TextStyle.lerp(metricLabel, other.metricLabel, t)!,
      metricValue: TextStyle.lerp(metricValue, other.metricValue, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      alarmTitle: TextStyle.lerp(alarmTitle, other.alarmTitle, t)!,
    );
  }
}
```

在主题中注册：

```dart
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: const TextTheme(
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.supporting,
      bodySmall: AppTypography.caption,
      titleMedium: AppTypography.control,
      titleLarge: AppTypography.sectionTitle,
      headlineSmall: AppTypography.pageTitle,
      headlineMedium: AppTypography.dialogTitle,
    ),
    extensions: const [
      CyberGlassTheme(),
      HmiTypography(),
    ],
  );
}
```

---

## 8. 英文布局适配策略

### 8.1 避免固定文字宽度

不推荐：

```dart
SizedBox(
  width: 180,
  child: Text(label),
)
```

推荐：

```dart
Expanded(
  child: Text(
    label,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  ),
)
```

只有设备编号、数值列、右侧控件等明确需要稳定对齐的区域才使用固定宽度。

### 8.2 限制 `FittedBox` 使用范围

允许使用：

- 首页时钟；
- 仪表盘大数值；
- 特殊数字显示；
- 图标与数字组成的展示组件。

不建议使用：

- 按钮文案；
- Tab 文案；
- 设置项标题；
- 普通正文；
- 安全说明；
- 告警内容。

### 8.3 统一省略规则

| 文案类型 | 策略 |
|---|---|
| 导航和 Tab | 单行，极端情况省略 |
| 卡片标题 | 最多 2 行，非关键内容可省略 |
| 设置标题 | 最多 2 行 |
| 设置副标题 | 最多 3 行，必要时增加行高 |
| 表格普通内容 | 可省略 |
| 设备编号、错误码 | 不省略 |
| 告警正文、安全说明 | 不省略，使用滚动 |
| 按钮 | 优先单行，调整宽度或文案 |

### 8.4 最小字号限制

- 普通用户可见文案原则上不低于 `16`；
- 主要操作和设置标题不低于 `18`；
- 告警正文不低于 `18`；
- `12` 和 `14` 仅用于刻度、单位和次要元数据；
- 不允许因为英文较长而将单个控件缩小到低于角色最小字号。

---

## 9. 文案治理

### 9.1 所有用户文案进入 ARB

生产页面不得继续直接写用户可见英文或中文：

```dart
Text('Save Changes')
```

应改为：

```dart
Text(context.l10n.saveChanges)
```

允许保留的硬编码字符串：

- 协议名称；
- 文件扩展名；
- 固定单位；
- 设备型号；
- 调试日志；
- 内部错误标识。

### 9.2 英文文案编写规则

- 优先使用简短、明确的动词；
- 按钮避免完整句子；
- 标题避免不必要的冠词；
- 相同操作使用同一个英文词；
- 不使用全大写制造层级；
- Tooltip 和帮助说明可以更完整；
- 告警正文应说明“发生了什么、用户应该做什么、失败后联系谁”。

示例：

| 不推荐 | 推荐 |
|---|---|
| `Click here to save the changes` | `Save Changes` |
| `Please try again` | `Retry` |
| `The current operation has failed` | `Operation Failed` |
| `SELECTED ON HOME` | `Selected on home` |

### 9.3 长文案单独处理

免责声明、安全提示、告警说明等长文案不参与普通卡片和按钮的宽度规则，应使用：

- 独立滚动区域；
- 段落间距；
- 列表编号；
- 固定正文 Token；
- 不低于最小字号；
- 不使用省略号。

---

## 10. 自动化检测

### 10.1 禁止新增裸字号

迁移完成后，在 CI 中扫描业务目录：

```bash
if rg "fontSize\s*:" lib/features \
  --glob '!**/app_typography.dart' \
  --glob '!**/hmi_typography.dart' \
  --glob '!**/*_tokens.dart'; then
  echo "Do not define fontSize directly in feature code. Use Typography tokens."
  exit 1
fi
```

业务专用动态数字组件可以进入白名单，但必须说明原因。

### 10.2 英文溢出测试

为核心页面增加 Widget Test 或 Golden Test：

```dart
await tester.pumpWidget(
  buildTestApp(
    locale: const Locale('en'),
    size: const Size(1280, 800),
  ),
);

expect(tester.takeException(), isNull);
```

应覆盖：

- 英文 `1280 × 800`；
- 目标设备实际分辨率；
- 项目支持的最小分辨率；
- 中文 `1280 × 800` 基础回归。

测试时捕获：

- RenderFlex overflow；
- 文案被裁剪；
- 按钮宽度不足；
- Tab 布局跳动；
- 弹窗内容超出；
- 文案与右侧控件重叠。

### 10.3 最长英文文案测试

按组件类型维护一组压力测试文案：

```text
Navigation: Advanced Settings
Primary button: Restore Default Settings
Card title: Total Wire Consumption
Setting title: Lens Contamination Detection
Setting hint: 使用项目中最长的实际英文设置说明
```

组件开发时优先使用这些文案，而不是使用 `Title`、`Test` 等短占位符。

---

## 11. 迁移顺序

### 第一阶段：建立基础设施

1. 创建 `AppTypography`；
2. 创建 `HmiTypography`；
3. 注册到 `ThemeData`；
4. 建立字号角色和组件映射表；
5. 建立英文压力测试文案；
6. 固定当前 UI 截图作为迁移基线。

### 第二阶段：迁移公共组件

优先迁移一次可影响多个页面的组件：

1. 顶部状态栏和产品 Tab；
2. 设置页标题、设置行、输入框、Switch；
3. 公共按钮；
4. 卡片标题和指标组件；
5. 普通弹窗；
6. 告警和安全弹窗；
7. 表格、列表和选择器。

### 第三阶段：按业务模块迁移

建议顺序：

1. `settings`；
2. `status_bar`；
3. `monitor`；
4. `process_mode`；
5. `process_library`；
6. `warn_alarm`；
7. `safety_tips`；
8. 其他业务模块；
9. `ui/demo`。

优先处理英文最容易溢出的页面，不按文件数量机械推进。

### 第四阶段：文案治理

1. 将生产代码中的用户可见硬编码文案迁移到 ARB；
2. 统一英文术语；
3. 将全大写标题与命名类文案改为 PascalCase；完整说明句保持正常句式；
4. 缩短按钮和 Tab 文案；
5. 对长说明增加分段和滚动；
6. 检查 634 个英文键在核心页面中的显示效果。

### 第五阶段：移除旧 Token

当模块全部迁移后：

1. 删除重复的模块级字号常量；
2. 保留尺寸、间距、图标大小等非文字常量；
3. 删除临时语言判断字号；
4. 删除不再需要的 `FittedBox`；
5. 开启 CI 禁止新增裸字号。

---

## 12. 验收标准

### 英文界面

英文为主要验收语言，必须满足：

- 核心页面无 RenderFlex overflow；
- 主要按钮完整显示；
- Tab 和导航无明显截断；
- 设置标题和副标题不与右侧控件重叠；
- 卡片标题最多 2 行，指标位置保持稳定；
- 告警和安全内容完整可读；
- 选中与未选中状态切换时文字不发生宽度跳动；
- 不通过低于角色最小字号解决英文过长问题；
- 不依赖大量 `FittedBox` 维持布局。

### 中文界面

中文只进行基础回归，必须满足：

- 无严重溢出、遮挡和裁剪；
- 所有操作可点击；
- 文案语义正确；
- 页面层级与英文一致；
- 中文较短造成的额外留白可以接受；
- 不要求中文与英文每一处容器占位完全相同。

### 代码质量

- 业务页面不再直接声明常规 `fontSize`；
- 同一文字角色统一使用 Typography Token；
- 颜色状态通过 `copyWith` 修改，不覆盖字号；
- 数值统一使用等宽数字；
- 用户可见文案统一进入 ARB；
- 特殊字号均有明确用途和集中定义。

---

## 13. 最终目标

将当前分散的字号和文案处理方式收敛为：

```text
英文文案决定布局基准
        ↓
语义化 Typography Token
        ↓
公共组件统一文字规则
        ↓
业务页面只组合组件和状态
        ↓
英文严格验收，中文基础回归
        ↓
CI 阻止新增裸字号和布局回退
```

本次治理的重点不是把所有字号改成相同数字，而是让每一种文字角色都有稳定的字号、字重、行高、换行和溢出规则，并确保英文文案在目标设备上优先完整、稳定地显示。
