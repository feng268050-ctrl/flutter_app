## 目标

本文件面向**外部客户端（例如手机 App）**实现与 HMI 等效的“Monitor / Alarm Information”监视能力，解释 `command.stat_response`（以及本 change 的 `GET /v1/monitor/stat` SSE）中 `deviceStatus` 与 `deviceData` 的字段含义、取值规则，以及 HMI 当前哪些字段真正用于界面展示。

> 说明：本文件按 **“HMI 实际使用”** 与 **“仍会在 JSON 中出现但 HMI 未直接使用”** 两类整理。未用到的字段也按源码注释说明，方便外部客户端按需扩展。

---

## 1. HMI 实际使用的字段（按页面）

### 1.1 Monitor → Machine status

#### 1.1.1 Gauge（数值表盘）

来源：`deviceData`

- `**blowAirPressure`**（kPa）
  - HMI 用途：左侧表盘（Blow pressure）。
- `**pumpSourceCurrent**`
  - HMI 用途：右侧表盘（Pump source current）。
  - 注意：HMI 表盘单位显示为 “A”，但该字段本身是一个整型原始值；外部客户端如需工程单位对齐，需要确认下位机寄存器量纲与 UI 约定。

#### 1.1.2 状态勾选（Checkbox）

来源：`deviceStatus.machineStatusSeg1` 的 bit 位（HMI 使用 `DeviceStatus` 的便捷方法）

- **Laser**：`isLaserOn()`（Bit0）
- **Blow / air valve**：`isAirValveOn()`（Bit4）
- **Safety lock (ground lock)**：`isSafetyGroundLockLocked()`（Bit5）
- **Gun head switch**：`isGunSwitchOn()`（Bit9）
- **Red light**：`isRedLightOn()`（Bit3）
- **Wire feeding**：`isWireFeedingOn()`（Bit2）

#### 1.1.3 摄像头通讯（Checkbox）

来源：`deviceStatus`

- `**cameraStatus`**
  - 取值：`1`=healthy，`0`=fault
  - HMI 用途：Machine status 中“Camera”一项（此前为独立信号，现已收敛到快照字段）。

---

### 1.2 Monitor → Alarm Information

#### 1.2.1 “就绪/离线”门控（很关键）

来源：`deviceStatus`

- `**deviceType**`
  - HMI 判定“已拿到真实下位机状态”的门槛：`deviceType != null && deviceType > 0`
  - 含义（源码注释）：`0`=未知，`1`=LSW01 控制板（其他预留）
  - UI 行为：未 ready 时，通讯状态/温度卡片显示为 NEUTRAL（灰），避免默认展示“全部正常”。

#### 1.2.2 通讯状态卡片（Communication status）

来源：`deviceStatus`（告警 bit），并由 UI 层做“ready/emulator”语义折叠。

- **Laser device comm**：`isLaserCommunicationAlarm()`（`laserAlarmSeg1` Bit0）
- **Gun head comm**：`isGunCommunicationAlarm()`（`gunAlarmSeg1` Bit0）
- **Wire feeder comm**：`isWireFeederCommunicationAlarm()`（`wireFeederAlarmSeg1` Bit0）
- **Camera comm**：`cameraStatus`（`1` healthy / `0` fault）

UI 显示折叠（供外部客户端复刻）：

- 若 `statusReady && !commAlarm` → HEALTHY（绿）
- 若 emulator → NEUTRAL（灰）
- 否则 → FAULT（红）

其中 `commAlarm` 在 HMI 中是“通讯告警位是否为 1”（例如 `isGunCommunicationAlarm()`）。

#### 1.2.3 温度/指标卡片（Temperature / metrics）

来源：`deviceData`（原始值）+ `deviceStatus`（告警 bit）。

**共同规则（来自 `DeviceData` 注释/实现）：**

- 温度字段为“原始值”，按规则显示：有符号数、扩大 10 倍，显示时除以 10 保留 1 位小数。
- 特殊值：`<= -999` 代表未连接/错误（HMI 视为无读数，展示 `- ℃` 且卡片为 NEUTRAL）。

逐项：

- **Gun motor temperature**
  - 原始值：`gunMotorTempRaw`
  - 告警位：`isGunMotorOverTemperatureAlarm()`（`gunAlarmSeg2` Bit0）
- **Motor driver board temperature**
  - 原始值：`gunDriverBoardTempRaw`
  - 告警位：`isDriverTemperatureAlarm()`（`gunAlarmSeg2` Bit1）
- **Protective lens temperature**
  - 原始值：`protectionBoardTempRaw`
  - 告警位：`isProtectionBoardTemperatureAlarm()`（`gunAlarmSeg2` Bit2）
- **Collimator / straight track temperature**
  - 原始值：`collimatorTempRaw`
  - 告警位：`isStraightTrackTemperatureAlarm()`（`gunAlarmSeg2` Bit3）

UI 显示折叠（供外部客户端复刻）：

- 若 `!ready || !hasValue` → NEUTRAL（灰）
- 否则若 `fault` → FAULT（红）
- 否则 → HEALTHY（绿）

其中：

- `ready` = `statusReady && dataReady`（HMI 仅在状态与数据都 ready 时显示非灰）
- `hasValue` = 对应温度 raw 值 `> -999`

---

## 2. 仍会在 JSON 中出现但 HMI 未直接用到的字段

### 2.1 `deviceData`（DeviceData）字段清单（按源码注释）

- `**blowAirPressure`**：吹气气压（kPa）。（HMI：Machine status 表盘使用）
- `**gunMotorTempRaw**`：枪头电机温度原始值；规则：有符号、扩大10倍；`<=-999` 未连接/错误；`200.0` 超温会报警。（HMI：Alarm Information 使用）
- `**gunDriverBoardTempRaw**`：枪头电机驱动板温度原始值；规则同上。（HMI：Alarm Information 使用）
- `**protectionBoardTempRaw**`：保护镜温度原始值；规则同上。（HMI：Alarm Information 使用）
- `**collimatorTempRaw**`：聚焦镜侧温原始值；规则同上。（HMI：Alarm Information 使用）
- `**gun24vVoltage**`：枪头 24V 电压（0–36V）。
- `**gun24vCurrent**`：枪头 24V 电流（0–2000mA）。
- `**forwardLightPdVoltage**`：前向光 PD 电压。（`@Deprecated`）
- `**laserFeedbackPower**`：激光反馈功率（单位 0.1W）。
- `**pumpSourceBoardTemperature**`：泵源板温度。
- `**pumpSourceTemperature**`：泵源温度。
- `**laserCurrent**`：激光器电流。
- `**laserRedCurrent**`：激光器红光电流。
- `**pumpSourceCurrent**`：泵源电流。（HMI：Machine status 表盘使用）
- `**environmentTemperature**`：环境温度。

> 外部客户端如果要做“更完整的 Alarm Information / 诊断页”，可以直接显示这些字段的工程值（温度按 0.1℃ 规则），并结合 `deviceStatus` 的告警位（例如泵源板温度告警等）做红/绿/灰状态。

### 2.2 `deviceStatus`（DeviceStatus）字段清单（按源码注释）

> `DeviceStatus` 字段主要是“状态字/告警状态字/寄存器段”，很多字段是 bitfield（16bit），需要按注释的 bit 位语义解析。

- `**cameraStatus**`：摄像头通讯状态（HTTP 探测），`1` healthy / `0` fault。（HMI：Machine status + Alarm Information 使用）

**0000H-0008H：OTA 升级相关**

- `deviceType`：设备类型（0未知；1 LSW01 控制板；其他预留）。（HMI：Alarm Information ready 门控使用）
- `hardwareVersion`：设备硬件版本
- `softwareVersion`：设备软件版本
- `otaUpgradeCmd`：OTA 升级命令（0x0000 无效；0x1234 请求固件信息；0x65A4 请求固件数据；0x1212 成功；0x0020 失败）
- `reqHardFirmwareVersion`：请求固件版本硬件
- `reqSoftwareVersion`：请求软件版本
- `reqFirmwareOffsetLow` / `reqFirmwareOffsetHigh`：请求固件偏移地址低/高字节
- `reqFirmwareDataLength`：请求固件数据长度

**0009H-000CH：枪头告警状态字**

- `gunAlarmSeg1`：Bit0 枪头通信；其余预留
- `gunAlarmSeg2`：Bit0 电机过温；Bit1 驱动温度；Bit2 保护镜温度；Bit3 直道温度；Bit4 24V 欠压；Bit5 驱动过流；Bit6 电机轨迹异常；Bit7 电机堵转；其余预留
- `gunAlarmSeg3`：Bit0 传感器通道差异；Bit1 静态电流异常；Bit2 电机连接线开路；Bit3 传感器异常；Bit4 FLASH 出错；Bit5 FLASH 未加密；其余预留
- `gunAlarmSeg4`：Bit0 MMI 晶振异常；Bit1 硬件总线错误；Bit2 内存管理异常；Bit3 内存访问出错；Bit4 非法指令；Bit5 看门狗重启；其余预留

**000DH-0011H：激光器告警状态字**

- `laserAlarmSeg1`：Bit0 激光器通信；Bit1 泵源板温度；Bit2 泵源温度；Bit3 电流；Bit4 红光电流；Bit5 泵源电压；Bit6 前向光 PD 电压；其余预留
- `laserAlarmSeg2`：Bit0–Bit3 1~4号驱动通讯；Bit4 AD反馈通讯；Bit5 泵浦模块超温；Bit6 驱动模块超温；Bit7 水温超限；Bit8 光纤温度超上限；Bit9 激光反射能量超上限；Bit10 激光输出能量超下限；Bit11 二极管短路；Bit12 光纤断开；Bit13 内部湿度超上限；Bit14 冷水互锁；Bit15 急停
- `laserAlarmSeg3`：Bit0 定位光故障；Bit1 窄脉冲保护；Bit2~Bit15 预留
- `laserAlarmSeg4`：预留

**0012H-0013H：送丝机告警状态字**

- `wireFeederAlarmSeg1`：Bit0 送丝机通信；Bit1 电流告警；其余预留
- `wireFeederAlarmSeg2`：预留

**0014H-0016H：控制卡 + 机台状态字**

- `controlCardAlarmSeg1`：预留（但代码里用 Bit0~Bit3 解析“气压/进气/压力传感器通讯/外部 flash 故障”等）
- `controlCardAlarmSeg2`：预留
- `machineStatusSeg1`：Bit0 激光状态；Bit1 枪头开关；Bit2 送丝状态；Bit3 红光状态；Bit4 气阀状态；Bit5 安全地锁状态；Bit6 钥匙开关；Bit7 急停开关；Bit8 安全门；Bit9~Bit15 预留
- `machineStatusSeg2`：预留

**0017H-002FH：预留段**

- `reserveSeg1` .. `reserveSeg25`：预留字段（均 `@Deprecated`）
