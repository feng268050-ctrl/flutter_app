# Monitor：Alarm 合并至 Machine Status 开发方案（修订版）

## 1. 目标

将 Monitor 中独立的 `Alarms` 顶层 Tab 合并到 `Machine Status`。

最终 Monitor 顶层导航：

```
Monitor
├── Work Info
├── Machine Status
├── Videos
└── AI Vision
```

删除独立：

```
Alarms
```

新的 `Machine Status` 统一承载：

1. Live Status
2. Device Health
3. Alarm Logs

> 不再单独增加 `Active Alarms` Section，避免与 `Alarm Logs` 在内容和功能上重复。

---

# 2. 最终 Machine Status 页面结构

```
Machine Status
│
├── LIVE STATUS
│   ├── Gas Pressure Gauge
│   ├── Laser Current Gauge
│   └── 4 个关键状态 Tile
│
├── DEVICE HEALTH
│
└── ALARM LOGS
```

页面采用统一纵向 Scroll，不在 Machine Status 内增加二级 Tab。

---

# 3. Live Status

首屏布局：

```
┌──────────────────────────────────────────────┐
│ [ Gas Pressure ]       [ Laser Current ]     │
│                                              │
│ [ Safety Clamp ] [ Gun Switch ] [ Red ] [ Camera ] │
└──────────────────────────────────────────────┘
```

保留：

```
Safety Clamp
Gun Switch
Red Pointer
Camera
```

删除 Machine Status 首屏中的：

```
Laser
Gas Flow
Wire Feeder
```

对应 UI 列表调整为：

```
final tiles = <(String, bool?)>[
  (l10n.safetyLockText, s?.safetyLockOn),
  (l10n.gunHeadSwitchText, s?.gunSwitchOn),
  (l10n.redLightText, s?.redLightOn),
  (l10n.ipCameraText, s?.cameraOn),
];
```

本次仅移除 UI 展示，不删除对应 Controller / Modbus 数据：

```
laserOn
blowOn
wireFeedingOn
```

这些数据仍可继续供 Process Mode、安全逻辑及其他业务模块使用。

---

# 4. Device Health

原 `AlarmInformationTab` 中的设备通信和温度状态迁移到：

```
DEVICE HEALTH
```

保留：

## Laser Device

```
Pump Communication
```

## Welding Gun

```
Gun Communication
Camera Communication

Motor Temperature
Motor Driver Temperature

Protective Mirror Temperature
Collimator Temperature
```

## Wire Feeder

```
Wire Feeder Communication
```

注意：

```
Wire Feeder 运行状态 Tile
```

从 Live Status 删除，但：

```
Wire Feeder Communication
```

仍属于设备健康诊断，需要保留。

同理：

```
Camera
```

表示运行状态；

```
Camera Communication
```

表示通信健康状态。

两者可以同时存在。

---

# 5. Alarm Logs

原独立 Alarm 页中的历史告警列表迁移到 Machine Status 最后一个 Section：

```
ALARM LOGS
```

保留现有：

```
warn.watchHistory(limit: 200)
```

以及：

```
warn.clearHistory()
```

继续复用：

```
MonitorAlarmLogRow
MonitorFrostActionButton
showAlarmLogsClearedDialog
```

---

## 5.1 不再增加 Active Alarms

删除原规划中的：

```
ACTIVE ALARMS
```

原因：

- 与 `Alarm Logs` 信息展示重复；
- 会增加页面层级和认知负担；
- 当前需求只需要一个统一告警记录入口。

最终 Machine Status 中只保留：

```
ALARM LOGS
```

作为告警信息展示区域。

---

## 5.2 Alarm Logs 展示建议

不建议在单页直接展开全部 200 条。

推荐默认显示：

```
Latest 10
```

或：

```
Latest 20
```

如果后续需要完整历史记录，可再增加：

```
View All
```

当前阶段如果不新增二级页面，则直接限制列表高度或显示最近若干条。

---

## 5.3 Clear 行为

保留：

```
Clear Alarm Logs
```

不要改成：

```
Clear Alarms
```

因为当前功能清理的是：

```
History Logs
```

不是解除设备当前 Fault。

---

# 6. 页面滚动结构

整合后建议从：

```
Column + Expanded
```

调整为：

```
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(
      child: _MachineLiveStatusSection(...),
    ),
    SliverToBoxAdapter(
      child: _MachineDeviceHealthSection(...),
    ),
    SliverToBoxAdapter(
      child: _MachineAlarmHistorySection(...),
    ),
  ],
)
```

最终页面只保留一个主 Scroll。

避免：

```
Outer Scroll
+
Nested ListView
+
Nested SettingsScrollView
```

---

# 7. AlarmInformationTab 拆分

不要直接：

```
MachineStatusTab(
  child: AlarmInformationTab(),
)
```

应拆出可复用 Section：

```
_MachineDeviceHealthSection
_MachineAlarmHistorySection
```

原：

```
AlarmInformationTab
```

完成迁移后删除。

---

# 8. Controller 关系

本次只整合 Presentation。

不要合并：

```
MachineStatusController
WarnAlarmController
```

## MachineStatusController

继续负责 Machine Status 实时运行数据。

生命周期：

```
Machine Status visible
→ start()

Machine Status hidden
→ stop()
```

## WarnAlarmController / WarnAlarmScope

继续保持 App 生命周期级运行。

负责：

```
Alarm Popup
Alarm Sound
Alarm History
Communication Fault
Temperature Health
```

即使用户离开 Machine Status 页面，也不能停止告警监控。

核心原则：

> **Merge Presentation, keep Controllers separated.**

---

# 9. Monitor 顶层 Tab 调整

当前：

```
tabWorkInformation = 0
tabMachineStatus = 1
tabAlarmInformation = 2
tabVideos = 3
tabAiVision = 4
```

调整为：

```
tabWorkInformation = 0
tabMachineStatus = 1
tabVideos = 2
tabAiVision = 3
```

删除：

```
tabAlarmInformation
```

同时从 Tab 配置删除：

```
Alarms
warning icon
AlarmInformationTab
```

---

# 10. 最终页面视觉

```
MACHINE STATUS
────────────────────────────────────────────

[        Gas Pressure        ] [       Laser Current       ]

[ Safety Clamp ] [ Gun Switch ] [ Red Pointer ] [ Camera ]


DEVICE HEALTH
────────────────────────────────────────────

Laser Device
[ Pump Communication ]

Welding Gun
[ Gun Communication ] [ Camera Communication ]

[ Motor Temperature ] [ Motor Driver Temperature ]

[ Protective Mirror Temperature ]
[ Collimator Temperature ]

Wire Feeder
[ Wire Feeder Communication ]


ALARM LOGS
────────────────────────────────────────────

[ A001 ...                          14:30 ]
[ C002 ...                          14:21 ]
[ ...                                    ]

                         [ Clear Alarm Logs ]
```

---

# 11. 实施优先级

## P0

```
Monitor 5 Tabs
→
Monitor 4 Tabs
```

删除独立 Alarm Tab。

## P1

Machine Status 首屏：

```
7 Status Tiles
→
4 Status Tiles
```

仅保留：

```
Safety Clamp
Gun Switch
Red Pointer
Camera
```

## P2

迁移原 Alarm 页内容：

```
Device Health
Alarm Logs
```

不增加：

```
Active Alarms
```

## P3

页面改为统一：

```
CustomScrollView / Sliver
```

## P4

清理：

```
AlarmInformationTab
tabAlarmInformation
无用 import
旧 Tab index
```

---

# 12. 验收标准

1. Monitor 顶层只剩 `Work Info / Machine Status / Videos / AI Vision`。
2. Machine Status 首屏保持两个 Gauge。
3. 状态 Tile 仅显示：
  - Safety Clamp
  - Gun Switch
  - Red Pointer
  - Camera
4. `Laser / Gas Flow / Wire Feeder` 不再作为首屏状态 Tile。
5. 删除 Tile 不影响对应 Controller / Modbus 数据。
6. Device Health 保留通信和温度检测。
7. `Wire Feeder Communication` 继续保留。
8. Machine Status 不再出现独立 `Active Alarms` Section。
9. 告警信息统一通过 `Alarm Logs` 展示。
10. `Clear Alarm Logs` 只清历史记录，不解除当前 Fault。
11. WarnAlarmController 在离开 Machine Status 后仍持续工作。
12. 页面只有一个主滚动容器，不出现 Nested Scroll 冲突。

---

# 13. 最终开发要求

> **将 Monitor 中独立的 Alarms Tab 合并到 Machine Status，并将 Machine Status 调整为** `Live Status → Device Health → Alarm Logs` **三段式页面结构。取消原规划中的** `Active Alarms` **Section，避免与 Alarm Logs 内容和功能重复，所有告警记录统一在** `Alarm Logs` **中展示。**
>
> **Live Status 首屏保留 Gas Pressure、Laser Current 两个 Gauge，并将状态 Tile 精简为 Safety Clamp、Gun Switch、Red Pointer、Camera 四项；Laser、Gas Flow、Wire Feeder 仅从 UI 中移除，不删除底层实时数据。Device Health 保留原 Alarm 页面中的通信与温度检测；Alarm Logs 保留历史记录订阅与 Clear Alarm Logs 能力。**

