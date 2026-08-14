# Machine Status 仪表盘最终版开发需求

## 1. 目标

将 `Machine Status` 页面中的 **Gas Pressure** 与 **Laser Current** 两个仪表盘统一升级为最终确认样式。

本次改动仅调整仪表盘的视觉结构、刻度布局和进度表现，保留现有：

- 数据来源
- 数值范围
- 数值动画
- 业务逻辑
- Machine Status 页面整体布局
- Status Tile 状态卡片

---

## 2. 最终视觉结构

仪表盘统一采用以下层级：

```text
Outer Scale / Tick Labels
        ↓
Gauge Background Ring Surface
        ↓
Active Progress Overlay
        ↓
Center Dial Surface
        ↓
Current Value
        ↓
Unit
        ↓
Bottom Info Cabin
        ↓
Gauge Name
```

其中：

- 外圈显示项目真实刻度值；
- 中心显示当前值；
- 当前值下方显示单位；
- 底部信息舱显示仪表名称；
- 橙色部分表示当前值进度。

---

# 3. 仪表盘数字与刻度

## 3.1 Gas Pressure

量程：

```text
0 ~ 1500 kPa
```

Major Tick：

```text
0
150
300
450
600
750
900
1050
1200
1350
1500
```

规则：

```text
min  = 0
max  = 1500
step = 150
```

总计：

```text
11 Major Ticks
10 Intervals
```

顶部保持：

```text
750
```

起点保持：

```text
0
```

终点保持：

```text
1500
```

---



## 3.2 Laser Current

量程：

```text
0 ~ 100 A
```

Major Tick：

```text
0
10
20
30
40
50
60
70
80
90
100
```

规则：

```text
min  = 0
max  = 100
step = 10
```

总计：

```text
11 Major Ticks
10 Intervals
```

顶部：

```text
50
```

---



# 4. Internal Scale：刻度位于轨道内部

最终刻度定义为：

> **Internal Scale**

即 Major Tick / Minor Tick 均绘制在 `Gauge Ring Surface` 内部，而不是轨道外侧。

要求：

- Tick 与 Ring Surface 共圆心；
- Tick 沿 Ring Surface 内缘径向绘制；
- Major Tick 较长、较粗；
- Minor Tick 较短、较细；
- Major Tick Label 位于 Tick 的内侧；
- Label 保持水平，不沿圆周旋转；
- Minor Tick 不显示数字；
- 左右两个 Gauge 使用完全相同的刻度几何规则。

推荐层级：

```text
Major Tick
→ Primary Scale

Minor Tick
→ Secondary Scale
```

---



# 5. Gauge Ring Surface 与进度关系

这是本次最重要的实现要求。

## 5.1 Ring Surface 本身就是进度轨道

仪表盘的深色环形背景面定义为：

> **Gauge Ring Surface**

该 Ring Surface 同时承担：

1. 仪表盘主体背景；
2. 未激活进度区域；
3. 当前值进度的承载面。

因此：

> **不允许额外再绘制一条独立的粗灰色 Background Track。**

---



## 5.2 错误结构

禁止：

```text
Gauge Ring Surface
+
Gray Background Track
+
Orange Progress Arc
```

这会形成两套弧形结构，视觉重复。

---



## 5.3 正确结构

统一改为：

```text
Gauge Ring Surface
+
Orange Active Progress Overlay
```

即：

- 深色 Ring Surface 本身表示完整未激活范围；
- 橙色进度直接覆盖在 Ring Surface 上；
- Orange Progress 与 Ring Surface 使用同一几何路径。

开发术语：

> **Integrated Ring Progress**

或：

> **Progress Overlay on Gauge Ring Surface**

---



# 6. Orange Progress

橙色部分仅表达：

> **Current Value Progress**

进度值：

```text
progress =
(currentValue - min) / (max - min)
```

并限制在：

```text
0.0 ~ 1.0
```

---



## 6.1 Progress 方向

保持现有项目的弧形增长方向：

```text
Start
左下
 ↓
Clockwise
 ↓
Top
 ↓
右侧
 ↓
End
右下
```

---



## 6.2 Progress 与 Ring Geometry 必须一致

Orange Progress 必须与 Gauge Ring Surface：

- 共圆心；
- 共半径；
- 共起始角；
- 共 Sweep Angle；
- 共 Ring Thickness；
- 共端点形状。

即：

```text
Progress Geometry
==
Ring Surface Geometry
```

区别仅在 Sweep Length。

---



## 6.3 绘制逻辑

推荐：

```dart
// 1. Draw the complete dark gauge ring surface.
drawGaugeRingSurface();

// 2. Draw the orange current-value progress directly over the same ring.
drawGaugeProgress(
  sweepAngle: fullSweepAngle * progress,
);
```

不要继续：

```dart
drawGrayBackgroundTrack();
drawOrangeProgressTrack();
```

---



# 7. Center Dial Surface

Ring Surface 内部保留独立的中心仪表面：

> **Center Dial Surface**

视觉要求：

- 深黑 / 深灰；
- 与 Ring Surface 有明确层级；
- 可使用非常轻微的径向渐变；
- 不使用明显 Glow；
- 不需要额外粗描边。

---



# 8. Center Readout

中心区域只显示：

```text
Current Value
Unit
```

例如：

```text
0
kPa
```

和：

```text
0
A
```

不再在中心显示：

```text
Gas Pressure
Laser Current
```

---



## 8.1 Layout

推荐：

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(value),
    SizedBox(height: valueUnitGap),
    Text(unit),
  ],
)
```

要求：

- Value 水平居中；
- Unit 位于 Value 正下方；
- Value 为最高文字层级；
- Unit 不影响 Value 的几何中心。

---



# 9. Bottom Info Cabin

仪表名称统一放在底部信息舱：

Gas：

```text
Gas
Pressure
```

Laser：

```text
Laser
Current
```

该区域定义为：

> **Integrated Gauge Name Pod**

---



## 9.1 Two-line Centered Gauge Name

名称允许按单词边界换行：

```text
maxLines = 2
textAlign = center
```

禁止：

```text
Gas Pressu...
Laser Curr...
```

核心 Gauge Name 不使用 Ellipsis。

推荐：

```dart
Text(
  title,
  maxLines: 2,
  softWrap: true,
  textAlign: TextAlign.center,
  overflow: TextOverflow.visible,
)
```

---



## 9.2 Name Pod 不是 Button

Bottom Info Cabin 仅承担信息展示：

- 无 Hover；
- 无 Pressed；
- 无点击行为；
- 不使用 Button Padding；
- 不采用 Button 视觉状态。

---



# 10. Painter 与 Widget 职责

最终仪表盘继续采用代码绘制，不使用 PNG 作为 UI 底图。

## CustomPainter 负责

```text
Gauge Ring Surface
Orange Active Progress Overlay
Center Dial Surface
Outer Rim
Major Tick
Minor Tick
Bottom Cabin Path（如采用异形 Path）
```



## Flutter Widget / Text 负责

```text
Major Tick Label
Current Value
Unit
Gauge Name
```

原因：

- 支持 ARB 多语言；
- 支持全局 Typography；
- 支持 Small / Default / Large；
- 避免 Canvas Text 与 Flutter Text 排版不一致。

---



# 11. 组件结构

建议继续使用：

```text
CurrentArcGauge
```

并建立最终视觉模式：

```dart
enum GaugeVisualStyle {
  horseshoe,
  integratedRing,
}
```

Machine Status 使用：

```dart
visualStyle: GaugeVisualStyle.integratedRing
```

---



# 12. Painter 拆分

不建议继续在旧 `_CurrentArcPainter` 中堆叠视觉条件。

新增：

```text
_IntegratedRingGaugePainter
```

结构：

```text
CurrentArcGauge
│
├── horseshoe
│   └── _CurrentArcPainter
│
└── integratedRing
    └── _IntegratedRingGaugePainter
```

避免影响其他旧 Gauge 使用场景。

---



# 13. Machine Status 配置

Gas Pressure：

```dart
CurrentArcGauge(
  value: s?.gasPressureKpa ?? 0,
  min: 0,
  max: 1500,
  majorTickEvery: 150,
  unit: 'kPa',
  title: l10n.gasPressureLabel,
  visualStyle: GaugeVisualStyle.integratedRing,
)
```

Laser Current：

```dart
CurrentArcGauge(
  value: s?.laserCurrentA ?? 0,
  min: 0,
  max: 100,
  majorTickEvery: 10,
  unit: 'A',
  title: l10n.laserCurrentLabel,
  visualStyle: GaugeVisualStyle.integratedRing,
)
```

---



# 14. Major / Minor Tick

建议：

```text
Gas Pressure
Major = 150 kPa

Laser Current
Major = 10 A
```

两个 Gauge 均：

```text
11 Major Ticks
10 Intervals
```

Minor Tick 建议每两个 Major 之间：

```text
1 ~ 2
```

当前 Gauge 尺寸有限，不建议过密。

Minor Tick：

- 不显示 Label；
- Stroke Width 小于 Major；
- Opacity 低于 Major。

---



# 15. 数值与进度动画

保留现有：

```text
AnimationController
Tween<double>
CurvedAnimation
```

数值变化时：

```text
Current Value
+
Orange Progress
```

必须同步更新。

推荐动画时长：

```text
300 ~ 600 ms
```

数据连续变化时，从当前动画值继续 Tween 到新值，不重新从 0 开始。

---



# 16. Typography

Gauge 属于 Display Typography。

建议统一：

```text
gaugeValue
gaugeUnit
gaugeTickLabel
gaugeName
```

由：

```text
HmiDisplayTypography
```

集中管理。

业务页面不直接写裸 `fontSize`。

---



# 17. 视觉验收标准



## Ring Surface

- 只存在一套 Gauge Ring Surface；
- 不存在额外灰色粗背景 Track；
- 未激活区域就是深色 Ring Surface；
- Orange Progress 直接覆盖同一 Ring。



## Progress

- 与 Ring 共圆心；
- 与 Ring 共半径；
- 与 Ring 共厚度；
- 从左下按当前值顺时针增长；
- 不漂浮在 Ring 外部或内部形成第二条弧。



## Scale

- Major / Minor Tick 均位于 Ring Surface 内；
- Tick 不在轨道外侧；
- Label 位于 Tick 内侧；
- Gas 与 Laser 刻度几何对称。



## Center

Gas：

```text
0
kPa
```

Laser：

```text
0
A
```



## Bottom Name Pod

完整两行显示：

```text
Gas
Pressure
```

```text
Laser
Current
```

不得省略。

---



# 18. 不调整范围

本次不修改：

- `MachineStatusController`
- Modbus 数据读取
- Gas Pressure 实际业务量程
- Laser Current 实际业务量程
- Status Tile
- Monitor Glass Card
- Tab
- Alarm 业务逻辑
- 其他 Monitor 页面

---



# 19. 最终开发术语

统一使用：

```text
Integrated Ring Gauge
一体化环形仪表盘

Gauge Ring Surface
仪表盘背景环形面

Integrated Ring Progress
一体化环面进度

Active Progress Overlay
当前值进度覆盖层

Internal Scale
轨道内部刻度

Major Tick
主刻度

Minor Tick
次刻度

Major Tick Label
主刻度数字

Center Dial Surface
中心仪表面

Center Readout
中心数值区

Current Value
当前值

Unit Label
单位

Integrated Gauge Name Pod
底部仪表名称舱

Two-line Centered Gauge Name
双行居中仪表名称
```

---



# 20. 一句话开发要求

> **Machine Status 的 Gas Pressure 与 Laser Current 仪表盘统一改为 Integrated Ring Gauge：项目真实刻度位于 Gauge Ring Surface 内部，深色 Ring Surface 本身即为完整未激活进度轨道，不再额外绘制灰色 Background Track；橙色 Current Value Progress 直接沿同一 Ring Surface 按当前值比例覆盖增长。中心只显示 Value + Unit，底部 Gauge Name Pod 使用最多两行居中方式完整显示 Gas Pressure / Laser Current。**

