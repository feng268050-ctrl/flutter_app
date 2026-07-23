# LWS UI 告警异常码参考

本文档汇总平板应用 **告警弹窗 / 告警日志** 使用的异常码（`AlarmCodeConstants` + `AlarmCodeEnums`），含计划新增的 **C002**。文案以 `**values-zh`** 为准；默认语言包为 `**values`**（英文）。

**数据来源**


| 项目                 | 位置                                                                                                                                |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| 异常码、注释中的文档级别       | `app/src/main/java/.../AlarmCodeConstants.java`                                                                                   |
| 弹窗标题/内容 string 资源  | `AlarmCodeEnums` → `app/src/main/res/values-zh/strings.xml`                                                                       |
| **运行时级别**（实际入库/弹窗） | `DeviceStatusConvert`：`createSeriousWarnTable` / `createWaitConfirmWarnTable` / `createIgnoreWarnTable` / `createRemoveWarnTable` |


**级别说明（运行时）**


| 级别    | 常量                               | 含义                                   |
| ----- | -------------------------------- | ------------------------------------ |
| 必须解决  | `WarnLevelConstant.SERIOUS`      | 严重告警，需处理                             |
| 可确认关闭 | `WarnLevelConstant.WAIT_CONFIRM` | 可确认后关闭                               |
| 忽略    | `WarnLevelConstant.IGNORE`       | 记录为主，弹窗策略较松                          |
| 解除    | `WarnLevelConstant.REMOVE`       | 对应 `**X`***** 码，表示原 `**E`***** 告警已解除 |


**系列前缀**


| 前缀    | 含义                                                                  |
| ----- | ------------------------------------------------------------------- |
| **A** | 气路/保护气等                                                             |
| **C** | **通讯（Communication）**；`C001` = 主控板 ↔ 平板 Modbus 通讯故障（见下文） |
| **E** | 激光器/泵浦等设备故障                                                         |
| **H** | 枪头（Handheld head）相关                                                 |
| **L** | 镜片（Lens）AI 污染                                                       |
| **W** | 送丝机（Wire feeder）                                                    |
| **X** | 对应 **E** 码的**解除**通知                                                 |


---

## 应用告警码一览（53）

> **说明**：部分 `**E010`–`E013`** 在 `AlarmCodeEnums` 中绑定的标题 string 与 `AlarmCodeConstants` 注释不完全一致，下表 **标题/内容** 以当前 **枚举实际引用的 string** 为准（即用户界面所见）。


| 代码        | 运行时级别 | 文档级别（Constants 注释） | 告警标题（中文）     | 告警内容（中文）                                        |
| --------- | ----- | ------------------ | ------------ | ----------------------------------------------- |
| **A001**  | 可确认关闭 | 必须解决               | 保护气告警        | 请检查保护气是否开启、气瓶是否缺气。如确认无误后机器仍报警，请联系售后服务。          |
| **E006**  | 必须解决  | 必须解决               | 泵浦模块超温告警     | 确认无误后机器仍报警，请联系客服协助。                             |
| **E008**  | 必须解决  | 必须解决               | 水温超上限告警      | 如确认一切正常后机器仍报警，请联系客服协助。                          |
| **E009**  | 必须解决  | 必须解决               | 光纤温度超上限告警    | 如确认一切正常后机器仍报警，请联系客服协助。                          |
| **E010**  | 必须解决  | 忽略                 | 激光反射能量超上限解除  | 联系 LaserCyber 售后团队                              |
| **E011**  | 必须解决  | 必须解决               | 激光输出能量低于下限告警 | 联系 LaserCyber 售后团队                              |
| **E012**  | 必须解决  | 必须解决               | 光纤断开告警       | 联系 LaserCyber 售后团队                              |
| **E013**  | 必须解决  | 必须解决               | 二极管短路故障解除    | 联系 LaserCyber 售后团队                              |
| **E014**  | 忽略    | 忽略                 | 泵源温度告警       | 联系 LaserCyber 售后团队                              |
| **E015**  | 忽略    | 忽略                 | 驱动模块超温告警     | 联系 LaserCyber 售后团队                              |
| **E016**  | 忽略    | 必须解决               | 内部湿度超上限告警    | 联系 LaserCyber 售后团队                              |
| **H001**  | 必须解决  | 必须解决               | 枪头通信告警       | 如果激光器和枪头之间存在通讯问题，请检查连接。若确认没有问题后机器仍报警，请联系售后服务协助。 |
| **H002**  | 忽略    | 忽略                 | 传感器通道偏差告警    | 联系 LaserCyber 售后团队                              |
| **H003**  | 忽略    | 忽略                 | 静态电流异常告警     | 联系 LaserCyber 售后团队                              |
| **H004**  | 忽略    | 忽略                 | 电机连接线开路告警    | 联系 LaserCyber 售后团队                              |
| **H005**  | 忽略    | 必须解决               | 传感器异常告警      | 联系 LaserCyber 售后团队                              |
| **H006**  | 忽略    | 忽略                 | FLASH 错误告警   | 联系 LaserCyber 售后团队                              |
| **H007**  | 忽略    | 忽略                 | FLASH 未加密告警  | 联系 LaserCyber 售后团队                              |
| **H008**  | 必须解决  | 必须解决               | 枪头电机过温告警     | 联系 LaserCyber 售后团队                              |
| **H009**  | 必须解决  | 必须解决               | 驱动温度告警       | 联系 LaserCyber 售后团队                              |
| **H010** | 必须解决  | 必须解决               | 保护镜温度告警      | 如果保护镜出现明显烧痕，请立即更换。                              |
| **H011** | 必须解决  | 必须解决               | 聚焦镜温度告警      | 检查聚焦镜。若保护镜有明显烧痕，请立即更换。                          |
| **H012** | 必须解决  | 必须解决               | 24V 欠压告警     | 联系 LaserCyber 售后团队                              |
| **H013** | 必须解决  | 必须解决               | 振镜电机过流告警     | 联系 LaserCyber 售后团队                              |
| **H014** | 必须解决  | 必须解决               | 振镜电机轨迹异常     | 联系 LaserCyber 售后团队                              |
| **H015** | 必须解决  | 必须解决               | 振镜电机堵转告警     | 联系 LaserCyber 售后团队                              |
| **H016** | 忽略    | 忽略                 | MMI 振荡器故障告警  | 联系 LaserCyber 售后团队                              |
| **H017** | 忽略    | 必须解决               | 硬件总线错误告警     | 联系 LaserCyber 售后团队                              |
| **H018** | 忽略    | 必须解决               | 内存管理错误       | 联系 LaserCyber 售后团队                              |
| **H019** | 忽略    | 必须解决               | 内存访问错误       | 联系 LaserCyber 售后团队                              |
| **H020** | 忽略    | 忽略                 | 非法指令告警       | 联系 LaserCyber 售后团队                              |
| **H021** | 忽略    | 忽略                 | 看门狗复位事件      | 联系 LaserCyber 售后团队                              |
| **H022** | 必须解决  | 忽略                 | 激光器通信告警      | 联系 LaserCyber 售后团队                              |
| **H023** | 忽略    | 忽略                 | 激光器电流告警      | 联系 LaserCyber 售后团队                              |
| **H024** | 忽略    | 忽略                 | 红光电流告警       | 联系 LaserCyber 售后团队                              |
| **H025** | 忽略    | 忽略                 | 泵源电压告警       | 联系 LaserCyber 售后团队                              |
| **H026** | 忽略    | 忽略                 | 激光器驱动通信告警    | 联系 LaserCyber 售后团队                              |
| **H027** | 忽略    | 忽略                 | AD 反馈通信告警    | 联系 LaserCyber 售后团队                              |
| **H028** | 必须解决  | 忽略                 | 冷水互锁告警       | 联系 LaserCyber 售后团队                              |
| **H029** | 忽略    | 忽略                 | 激光器急停告警      | 联系 LaserCyber 售后团队                              |
| **H030** | 忽略    | 忽略                 | 定位光故障告警      | 联系 LaserCyber 售后团队                              |
| **H031** | 忽略    | 忽略                 | 窄脉冲保护告警      | 联系 LaserCyber 售后团队                              |
| **H032** | 忽略    | 忽略                 | 驱动板过压        | 联系 LaserCyber 售后团队                              |
| **H033** | 忽略    | 忽略                 | 环境温度告警       | 联系 LaserCyber 售后团队                              |
| **H034** | 必须解决  | 必须解决               | 零点偏移告警       | 零点偏移中心请及时校正                                        |
| **L001**  | 必须解决  | 必须解决               | 镜片脏污告警       | 保护镜严重脏污，需要清洁或更换保护镜片                                  |
| **W001**  | 可确认关闭 | 可确认关闭              | 送丝机通讯告警      | 联系 LaserCyber 售后团队                              |
| **W002**  | 可确认关闭 | 可确认关闭              | 送丝机电流告警      | 联系 LaserCyber 售后团队                              |
| **X006**  | 解除    | 必须解决               | 泵浦模块超温解除     | 联系 LaserCyber 售后团队                              |
| **X008**  | 解除    | 必须解决               | 水温超限解除       | 联系 LaserCyber 售后团队                              |
| **X009**  | 解除    | 必须解决               | 光纤温度超上限解除    | 联系 LaserCyber 售后团队                              |
| **X010**  | 解除    | 必须解决               | 激光反射能量超上限解除  | 联系 LaserCyber 售后团队                              |
| **X011**  | 解除    | 忽略                 | 激光输出能量低于下限解除 | 联系 LaserCyber 售后团队                              |
| **X012**  | 解除    | 必须解决               | 二极管短路故障解除    | 联系 LaserCyber 售后团队                              |
| **X013**  | 解除    | 必须解决               | 光纤断开解除       | 联系 LaserCyber 售后团队                              |


| **C001**  | 必须解决  | C = 通讯 | 主控板与平板通讯故障 | 主控板与平板通讯异常。请先关机，等待 10 秒后再开机。若开机后告警仍然出现，请联系售后服务。 |
| **C002**  | 必须解决  | C = 通讯 | 摄像头通信告警    | 主机与内置摄像头通讯异常。请先关机，等待 10 秒后再开机。若开机后告警仍然出现，请联系售后服务。 |
| **C003**  | 必须解决  | C = 通讯 | 主控板与温控板通讯故障 | 主控板与温控板之间通讯异常。请先关机，等待 10 秒后再开机。若开机后告警仍然出现，请联系售后服务。 |
| **C004**  | 必须解决  | C = 通讯 | 温控板与制冷系统通讯故障 | 温控板与制冷系统之间通讯异常。请先关机，等待 10 秒后再开机。若开机后告警仍然出现，请联系售后服务。 |

**C001 触发**：最近 5 次设备状态或设备数据 Modbus 轮询中，各自 ≥3 次不完整（状态 23 / 数据 19 个字段未全部读到）或请求失败；不完整时**丢弃**当次数据、不合并缓存。滑动窗口分别由 `ModbusStatusReadHealth`、`ModbusDataReadHealth` 维护，结果写入 `DeviceStatus.isModbusStatusReadTruncated()` / `DeviceData.isModbusDataReadTruncated()`；任一段达到阈值即告警。`DeviceStatusConvert.appendControllerTabletCommWarnTable`。

**C002 触发**：`CameraCommStatus.isFault()`（ICMP ping）；`CameraCommunicationWarnAlarm` + `WarnAlarmPipeline.onExternalFaultActive`。

---

## 英文标题与内容（默认 `values`）


| 代码       | Title (EN)                                 | Content (EN)                                                                                                                                                                                                                     |
| -------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A001     | Shielding Gas Alarm                        | Please check if the protective gas is on and if the gas cylinder is low. If the machine still alarms after confirming these are correct, please contact after-sales service.                                                     |
| E006     | Pump Module Overtemperature Alarm          | If the machine still alarms after confirming everything is correct, please contact customer service for assistance.                                                                                                              |
| E008     | Water Temperature Upper Limit Alarm        | If the machine still alarms after confirming everything is correct, please contact customer service for assistance.                                                                                                              |
| E009     | Fiber Temperature Upper Limit Alarm        | If the machine still alarms after confirming everything is correct, please contact customer service for assistance.                                                                                                              |
| E010     | Laser Reflected Energy Upper Limit Cleared | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| E011     | Laser Output Energy Lower Limit Alarm      | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| E012     | Fiber Disconnection Alarm                  | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| E013     | Diode Short Circuit Error Cleared          | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| E014     | Pump Source Temperature Alarm              | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| E015     | Driver Module Overtemperature Alarm        | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| E016     | Internal Humidity Upper Limit Alarm        | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H001     | Gun Head Communication Alarm               | If there is a communication problem between the laser and the laser head, please check the connection. If the machine still alarms after confirming that there is no problem, please contact after-sales service for assistance. |
| H002     | Sensor Channel Deviation Alarm             | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H003     | Quiescent Current Abnormal Alarm           | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H004     | Motor Cable Open Alarm                     | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H005     | Sensor Abnormal Alarm                      | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H006     | FLASH Error Alarm                          | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H007     | FLASH Unencrypted Alarm                    | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H008     | Gun Head Motor Overtemperature Alarm       | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H009     | Drive Overtemperature Alarm                | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H010    | Protective Lens Overtemperature Alarm      | If the protective lens shows obvious burn marks, please replace it immediately.                                                                                                                                                  |
| H011    | Collimating Lens Overtemperature Alarm     | Inspect the collimating lens. If the protective lens has obvious burn marks, replace it immediately.                                                                                                                             |
| H012    | 24V Undervoltage Alarm                     | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H013    | Galvanometer Motor Overcurrent Alarm       | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H014    | Galvanometer Motor Trajectory Error        | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H015    | Galvanometer Motor Stall Alarm             | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H016    | MMI Oscillator Malfunction Alarm           | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H017    | Hardware Bus Error Alarm                   | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H018    | Memory Management Error                    | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H019    | Memory Access Error                        | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H020    | Illegal Instruction Alarm                  | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H021    | Watchdog Reset Event                       | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H022    | Laser Communication Alarm                  | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H023    | Laser Current Alarm                        | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H024    | Red Light Current Alarm                    | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H025    | Pump Source Voltage Alarm                  | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H026    | Laser Driver Communication Alarm           | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H027    | AD Feedback Communication Alarm            | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H028    | Cold Water Interlock Alarm                 | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H029    | Laser Emergency Stop Alarm                 | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H030    | Positioning Light Fault Alarm              | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H031    | Narrow Pulse Protection Alarm              | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H032    | Driver Board Overvoltage                   | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H033    | Environment Temperature Alarm              | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| H034    | Zero Point Offset Alarm                    | Please correct the zero-point offset center promptly.                                                                                                                                                                           |
| L001     | Lens Contamination Alarm                   | Protective lens is heavily contaminated; clean or replace the protective lens.                                                                                                                                                 |
| W001     | Wire Feeder Communication Alarm            | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| W002     | Wire Feeder Current Alarm                  | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X006     | Pump Module Overtemperature Cleared        | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X008     | Water Temperature Limit Cleared            | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X009     | Fiber Temperature Upper Limit Cleared      | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X010     | Laser Reflected Energy Upper Limit Cleared | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X011     | Laser Output Energy Lower Limit Cleared    | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X012     | Diode Short Circuit Error Cleared          | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| X013     | Fiber Disconnection Cleared                | Contact LaserCyber After-Sales Team                                                                                                                                                                                              |
| **C001** | Controller–Tablet Communication Fault      | Please shut down the device, wait 10 seconds, then power on again. If the alarm persists after powering on, please contact after-sales service.                                                                                  |
| **C002** | Camera Communication Alarm                 | Please shut down the device, wait 10 seconds, then power on again. If the alarm persists after powering on, please contact after-sales service.                                                                                  |
| **C003** | Main Controller–Temperature Board Comm Fault | Please shut down the device, wait 10 seconds, then power on again. If the alarm persists after powering on, please contact after-sales service.                                                                                |
| **C004** | Temperature Board–Refrigeration Comm Fault | Please shut down the device, wait 10 seconds, then power on again. If the alarm persists after powering on, please contact after-sales service.                                                                                  |


---

## 附录 A：通讯类告警码速查


| 代码       | 对象            | 运行时级别 | 标题（中文）    |
| -------- | ------------- | ----- | --------- |
| H001     | 枪头 ↔ 下位机      | 必须解决  | 枪头通信告警    |
| H022    | 激光器           | 必须解决  | 激光器通信告警   |
| H026    | 激光器驱动         | 忽略    | 激光器驱动通信告警 |
| H027    | AD 反馈         | 忽略    | AD 反馈通信告警 |
| H034    | 产线零点检测        | 必须解决  | 零点偏移告警    |
| W001     | 送丝机           | 可确认关闭 | 送丝机通讯告警   |
| **C001** | 主控板 ↔ 平板 Modbus | 必须解决  | 主控板与平板通讯故障 |
| **C002** | 工业摄像头 ICMP     | 必须解决  | 摄像头通信告警   |
| **C003** | 激光模组故障表       | 必须解决  | 主控板与温控板通讯故障 |
| **C004** | 激光模组故障表       | 必须解决  | 温控板与制冷系统通讯故障 |


---

## 附录 B：激光模组 `warn_code` 表中的 C 码

`warn_code` / `warn_text` 数组与 `AlarmCodeConstants` 对齐：


| 代码   | 文案（中文）       | App 告警管线 |
| ---- | ------------ | -------- |
| C003 | 主控板与温控板通讯故障  | 已定义（`C003`），待固件位映射接入弹窗 |
| C004 | 温控板与制冷系统通讯故障 | 已定义（`C004`），待固件位映射接入弹窗 |

**C001** 保留给主控板与平板 Modbus 通讯故障（状态段与数据段各自 5 次读 3 次异常阈值）；工业摄像头使用 **C002**。

---

## 维护说明

- 实现 **C002** 或修改文案后，请同步更新本文档与 `AlarmCodeConstants` 注释。  
- 若调整 `AlarmCodeEnums` 与 string 绑定，以界面实测为准更新上表。  
- OpenSpec：`openspec/changes/monitor-camera-comm-status/`