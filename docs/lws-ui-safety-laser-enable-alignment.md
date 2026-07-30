# Process Mode 安全路径对齐 lws-ui（设计说明）

本文记录将 **lws-hmi**（Flutter）钥匙 / E-stop / Laser Enable / 告警预检对齐 **lws-ui**（Android）时的问题根因与后续对齐方案。  
对照代码：`lws-ui` 的 `EmergencyStopJobHaltPolicy`、`EngineerModeCheck`、`LaserEnableAlarmGuard`、`DeviceStatusConvert` / `ModbusFiledConvert.applyEmergencyStopCommAlarmReset`；本仓 `DeviceControlController`、`ModbusAlarmAttributeAdapter`、`LaserEnablePreflight`。

**状态：** §3 tip 时序与 §4 架构对齐主体已落地。剩余仅为板端冒烟与防回退约定；不必再堆边沿补丁。

---

## 1. 为何「按 lws-ui 复刻」仍出问题

不完全是漏抄几个 `if`，而是三层叠加：

1. **产品时序理解偏了**（tip vs 告警、钥匙 tip 与复位时机一度反了）。
2. **状态机模型不等价**：Android 偏「本地控制字 + 每轮电平快照」；HMI 偏「Modbus 边沿 + 本地位 + 可选 reconcile」。
3. **板端 Modbus 抖动**（写失败 / group-read 失败 / C001）把竞态放大成可见缺陷。

目标：**产品能力不少于 lws-ui**，对齐的是**操作员可见语义与守卫顺序**，不是逐行移植 Java。Flutter 侧用 `ChangeNotifier` / `AnimatedBuilder`、统一会话 getter、settle 后 `readAttribute` 电平确认来对齐语义。

---

## 2. 两边模型对照


| 维度 | lws-ui（Android） | lws-hmi（当前 Flutter） |
|------|-------------------|-------------------------|
| 作业开关 UI | `DeviceControlData` 先改本地，再写 holding | `DeviceControlController`；会话态 `laserSessionArmed` ≡ `laserEnable` |
| 安全关断写失败 | `switchLaserEnableStatus(false)` / `failRest=false`：**不回滚**本地关断 | `_disarmLaserSessionLocally` + `disableLaser(keepUiDisarmed:)`；reconcile 在钥匙关/急停下不复武装 |
| 急停 halt | `applyHaltAllJobFunctions` 同步本地全关 | `haltAllJobFunctions` + `_applyLocalJobHalt` |
| 设备状态 / 告警 | 轮询合并 `DeviceStatus`；急停下在快照里清 H022/W001 位后再算表 | `ModbusAlarmAttributeAdapter` **边沿**进 `WarnAlarmCoordinator` |
| 急停松开后 H022 等 | 下一拍电平再算 | settle（~400ms）后 **`readAttribute` 电平确认**再 rising |
| Laser Enable 被告警拦 | `LaserEnableAlarmGuard` → `requestImmediateShow` 弹出**该码** | `presentLaserEnableBlock` / `requestImmediateShow` |
| Tip 弹窗 | E-stop：按下一次；钥匙关：监听失败即 `OperationDialogBuilder` | 见 §3 |
| End of work / 侧栏 | **仅** `isOpenLaser()`（`laserStatus`） | **仅** `laserSessionArmed`（不用 `laserOn`） |

---

## 3. 已对齐 / 已验收方向的行为（tip 与安全关断）

操作员 tip（Frost Operation-failed，卡片局部高斯模糊 + 浅 tint 背景透视）与急停作业 halt：


| 事件 | 立刻 | Tip（Operation failed） | 告警 frost（H029 等） |
|------|------|-------------------------|------------------------|
| 按 E-stop | `halt` + 退出 Laser Enable 会话 UI | **按下**一次「Device is in E-stop」 | **复位后**再出（mask + settle） |
| Laser Enable 开着时关钥匙 | 退出 Laser Enable UI（写失败也保持关） | **关断时**「Key switch is off」 | 与钥匙相关的告警仍按复位/电平策略（非本 tip） |
| 钥匙 / E-stop 复位 | 不自动恢复 Laser Enable | 不再为 tip 复弹 | 按告警适配器 |

**不要**再把钥匙 tip 延到「钥匙重新打开」——那是 tip / 告警时机反了；E-stop tip 保持按下即出。

---

## 4. 架构对齐清单

### 4.1 安全路径：本地会话态权威（failRest=false） — ✅

**原则：** 凡安全关断（钥匙关、E-stop halt、退出卸武），**先**把 Laser Enable 会话 UI 置为关，再 best-effort 写 Modbus；写失败 / reconcile 读回 true **不得**在钥匙关或急停保持期间把 UI 重新武装。

**已落地：**

- `DeviceControlController.laserSessionArmed` ≡ `laserEnable`；Quick / Engineer / bar / Record Work 按钮与侧栏均跟会话位，不用 `laserOn`。
- `_disarmLaserSessionLocally` / `_applyLocalJobHalt` / `forceDisableLaserForSafety` / `disableLaser(keepUiDisarmed:)` 统一关断；reconcile 在 `!keySwitchOn || emergencyStop` 时压制复武装。
- 钥匙关期间压制 `control.laser_enable==true` 的 watch 回写（只清 UI）。

**验收：** 关钥匙或急停后，无论 RTU 是否失败，按钮必回「Laser Enable」、侧栏恢复；Back 不再因「仍开着」误走 `disableLaser` 打出 `Laser enable write failed`。

### 4.2 告警：急停期间按电平语义，松开后 settle 再采样 — ✅

**原则：** 对齐 `applyEmergencyStopCommAlarmReset`——急停保持时 H022 / W001（及产品约定的 H029）在**告警路径**视为无效；松开后不要用松开边沿的陈旧 raw 立刻 rising。

**已落地：**

- engage → effective false；release → **延迟 settle**（现约 400ms）再 **`readAttribute` 电平确认**后重采样；settle 内 raw 已清则不 rising。
- C001 仍可拦 Laser Enable（与 lws-ui 一致）；不特判放行。

**验收：** 仅急停一次且激光通讯位随复电清除时，不应长期卡在 H022；真故障位保持 true 时仍应拦并用该码弹窗。

### 4.3 Laser Enable 预检：弹具体告警，禁止笼统文案 — ✅

**原则：** 对齐 `LaserEnableAlarmGuard.blockLaserEnable` / `requestImmediateShow`。

**已落地：**

- 预检失败 `alarmBlocked` → `presentLaserEnableBlock`；Quick / Engineer / `DeviceControlBar` 均路由 tip / warn，不再 Toast「Alarm blocks laser enable」。
- `firstBlockingAlarmCode` 顺序：A001 → C002 → L001 → W001/W002 → other。
- 若该码弹窗已在屏上，静默返回 false，不叠第二层提示。

### 4.4 Tip vs 告警职责拆分（文档约定，防回退） — ✅ 约定

| 类型 | 载体 | 时机 |
|------|------|------|
| Tip | `DeviceControlSafetyEvent` → Operation-failed 深色霜（卡片局部高斯 + 背景透视） | E-stop 按下；钥匙关（Laser Enable 曾开） |
| 告警 | `WarnAlarmCoordinator` + frost warn | 码位有效边沿；急停相关 mask 在复位 + settle + 电平读后 |

禁止再次把 tip 延到「开关复位」来「代替」告警，或把 H022 误 rising 当成 tip。

### 4.5 回归与板端证据 — 单测 ✅ / 板端待操作员

- 单测：钥匙 tip 在 falling；E-stop tip 在 rising；钥匙关写失败 UI 仍关；急停 release settle + level-read H022；`laserSessionArmed` 不跟 `laserOn`；`presentLaserEnableBlock`。
- 板端：`journalctl -u hmi.service` 查 `WARN_DBG` rising/`device-control`；复现钥匙关→复位→Laser Enable、急停→复位→Laser Enable。

---

## 5. 建议实施顺序（历史）

1. ~~钉死 §3 时序~~  
2. ~~§4.1 会话态权威~~  
3. ~~§4.2 告警 settle / 电平~~  
4. ~~§4.3 预检弹窗路径扫尾~~  
5. 必要时再开 OpenSpec change，把本页链到 P4 process-mode 任务。

---

## 6. 相关路径（速查）

| 区域 | 路径 |
|------|------|
| 设备控制 / tip 边沿 | `app/lws_hmi/lib/features/process_mode/application/device_control_controller.dart` |
| Operation-failed tip UI | `app/lws_hmi/lib/features/process_mode/presentation/operation_failed_dialog.dart` |
| Quick / Engineer 绑定 | `quick_mode_device_controls.dart` / `engineer_device_panel.dart` |
| 预检 | `app/lws_hmi/lib/features/process_mode/domain/laser_enable_preflight.dart` |
| 急停 mask | `app/lws_hmi/lib/features/warn_alarm/infrastructure/estop_comm_alarm_mask.dart` |
| 告警适配 | `app/lws_hmi/lib/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart` |
| 拦启用弹窗 | `WarnAlarmController.presentLaserEnableBlock` / `WarnAlarmCoordinator.requestImmediateShow` |
| Android 对照 | `lws-ui` … `EmergencyStopJobHaltPolicy`、`LaserEnableAlarmGuard`、`ModbusFiledConvert.applyEmergencyStopCommAlarmReset` |

Process Mode UI 迁移总览见 [`process-mode-ui-migration-plan.md`](process-mode-ui-migration-plan.md)。
