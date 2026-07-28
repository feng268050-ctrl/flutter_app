# Process Mode 安全路径对齐 lws-ui（设计说明）

本文记录将 **lws-hmi**（Flutter）钥匙 / E-stop / Laser Enable / 告警预检对齐 **lws-ui**（Android）时的问题根因与后续对齐方案。  
对照代码：`lws-ui` 的 `EmergencyStopJobHaltPolicy`、`EngineerModeCheck`、`LaserEnableAlarmGuard`、`DeviceStatusConvert` / `ModbusFiledConvert.applyEmergencyStopCommAlarmReset`；本仓 `DeviceControlController`、`ModbusAlarmAttributeAdapter`、`LaserEnablePreflight`。

**状态：** 部分行为已按验收修正（见 §3）；§4 为仍待落地的架构对齐（验收通过当前包并提交后执行）。

---

## 1. 为何「按 lws-ui 复刻」仍出问题

不完全是漏抄几个 `if`，而是三层叠加：

1. **产品时序理解偏了**（tip vs 告警、钥匙 tip 与复位时机一度反了）。
2. **状态机模型不等价**：Android 偏「本地控制字 + 每轮电平快照」；HMI 偏「Modbus 边沿 + 本地位 + 可选 reconcile」。
3. **板端 Modbus 抖动**（写失败 / group-read 失败 / C001）把竞态放大成可见缺陷。

目标：**产品能力不少于 lws-ui**，对齐的是**操作员可见语义与守卫顺序**，不是逐行移植 Java。

---

## 2. 两边模型对照


| 维度 | lws-ui（Android） | lws-hmi（当前 Flutter） |
|------|-------------------|-------------------------|
| 作业开关 UI | `DeviceControlData` 先改本地，再写 holding | `DeviceControlController` 本地位；成功路径常再 `reconcile` |
| 安全关断写失败 | `switchLaserEnableStatus(false)` / `failRest=false`：**不回滚**本地关断 | 曾在写失败时仍保持 `laserEnable=true`（已部分修） |
| 急停 halt | `applyHaltAllJobFunctions` 同步本地全关 | `haltAllJobFunctions` + `_applyLocalJobHalt`（已对齐方向） |
| 设备状态 / 告警 | 轮询合并 `DeviceStatus`；急停下在快照里清 H022/W001 位后再算表 | `ModbusAlarmAttributeAdapter` **边沿**进 `WarnAlarmCoordinator` |
| 急停松开后 H022 等 | 下一拍电平再算；假阳性常已清 | 曾用**松开瞬间缓存 raw** 立刻 rising → 易粘住（已改为 settle 后再采样） |
| Laser Enable 被告警拦 | `LaserEnableAlarmGuard` → `requestImmediateShow` 弹出**该码** | 曾只 SnackBar「Alarm blocks laser enable」（已改为 `presentLaserEnableBlock`） |
| Tip 弹窗 | E-stop：按下一次；钥匙关：监听失败即 `OperationDialogBuilder` | 见 §3 |

---

## 3. 已对齐 / 已验收方向的行为（tip 与安全关断）

操作员 tip（Frost Operation-failed，无高斯模糊）与急停作业 halt：


| 事件 | 立刻 | Tip（Operation failed） | 告警 frost（H029 等） |
|------|------|-------------------------|------------------------|
| 按 E-stop | `halt` + 退出 Laser Enable 会话 UI | **按下**一次「Device is in E-stop」 | **复位后**再出（mask + settle） |
| Laser Enable 开着时关钥匙 | 退出 Laser Enable UI（写失败也保持关） | **关断时**「Key switch is off」 | 与钥匙相关的告警仍按复位/电平策略（非本 tip） |
| 钥匙 / E-stop 复位 | 不自动恢复 Laser Enable | 不再为 tip 复弹 | 按告警适配器 |

**不要**再把钥匙 tip 延到「钥匙重新打开」——那是 tip / 告警时机反了；E-stop tip 保持按下即出。

---

## 4. 待落地的架构对齐（验收通过并提交当前包之后）

下列项是「按模型对齐」，避免继续用边沿补丁堆叠。

### 4.1 安全路径：本地会话态权威（failRest=false）

**原则：** 凡安全关断（钥匙关、E-stop halt、退出卸武），**先**把 Laser Enable 会话 UI 置为关，再 best-effort 写 Modbus；写失败 / reconcile 读回 true **不得**在钥匙关或急停保持期间把 UI 重新武装。

**落地建议：**

- 统一「会话武装」判定：按钮文案 / 侧栏隐藏以 `laserEnable`（控制字会话）为准；`laserOn` 仅作发射反馈，不单独维持「End of work」会话。
- `forceDisableLaserForSafety` / `_applyLocalJobHalt` / `disableLaser(keepUiDisarmed:)` 收成一套私有策略，避免各路径行为漂移。
- 钥匙关期间忽略或压制 `control.laser_enable==true` 的 watch 回写（已有「只清 UI、不狂写」分支；保持并单测钉死）。

**验收：** 关钥匙或急停后，无论 RTU 是否失败，按钮必回「Laser Enable」、侧栏恢复；Back 不再因「仍开着」误走 `disableLaser` 打出 `Laser enable write failed`。

### 4.2 告警：急停期间按电平语义，松开后 settle 再采样

**原则：** 对齐 `applyEmergencyStopCommAlarmReset`——急停保持时 H022 / W001（及产品约定的 H029）在**告警路径**视为无效；松开后不要用松开边沿的陈旧 raw 立刻 rising。

**落地建议：**

- 保持：engage → effective false；release → **延迟 settle**（现约 400ms）再按当前 raw 重采样；settle 内 raw 已清则不 rising。
- 评估是否对 masked 属性增加「松开后一次显式 group/属性读」作电平确认，减少「位一直为 true 但无 change 边沿」的漏报（Android 每轮电平）。
- C001 仍可拦 Laser Enable（与 lws-ui 一致）；抖动治理属 Modbus 健康窗口，不在本 tip 里特判放行。

**验收：** 仅急停一次且激光通讯位随复电清除时，不应长期卡在 H022 导致无法 Laser Enable；真故障位保持 true 时仍应拦并用该码弹窗。

### 4.3 Laser Enable 预检：弹具体告警，禁止笼统文案

**原则：** 对齐 `LaserEnableAlarmGuard.blockLaserEnable` / `requestImmediateShow`。

**落地建议：**

- 预检失败 `alarmBlocked` → `presentLaserEnableBlock`（已有）；Quick / Engineer 全路径（含 hold 预检、`enableLaser` 二次预检）禁止再 SnackBar/Toast「Alarm blocks laser enable」。
- `firstBlockingAlarmCode` 顺序与 Android 一致：A001 → C002 → L001 → W001/W002 → other。
- 若该码弹窗已在屏上，静默返回 false，不叠第二层提示。

**验收：** 有活动告警时点 Laser Enable，只见对应 warn frost（或已有弹窗），不见笼统英文 snackbar。

### 4.4 Tip vs 告警职责拆分（文档约定，防回退）

| 类型 | 载体 | 时机 |
|------|------|------|
| Tip | `DeviceControlSafetyEvent` → Operation-failed 实心霜 | E-stop 按下；钥匙关（Laser Enable 曾开） |
| 告警 | `WarnAlarmCoordinator` + frost warn | 码位有效边沿；急停相关 mask 在复位 + settle 后 |

禁止再次把 tip 延到「开关复位」来「代替」告警，或把 H022 误 rising 当成 tip。

### 4.5 回归与板端证据

- 单测：钥匙 tip 在 falling；E-stop tip 在 rising；钥匙关写失败 UI 仍关；急停 release settle 前后 H022；`presentLaserEnableBlock` / `requestImmediateShow`。
- 板端：`journalctl -u hmi.service` 查 `WARN_DBG` rising/`device-control`；复现钥匙关→复位→Laser Enable、急停→复位→Laser Enable。

---

## 5. 建议实施顺序（提交当前包之后）

1. **钉死 §3 时序**（钥匙 tip 关断即出、E-stop 按下即出）——当前改动验收通过后提交。  
2. **§4.1** 会话态权威（消除 write failed / UI 假开）。  
3. **§4.2** 告警 settle / 电平（消除假 H022 粘连）。  
4. **§4.3** 预检弹窗路径扫尾（防笼统文案回潮）。  
5. 必要时再开 OpenSpec change，把本页链到 P4 process-mode 任务。

---

## 6. 相关路径（速查）

| 区域 | 路径 |
|------|------|
| 设备控制 / tip 边沿 | `app/lws_hmi/lib/features/process_mode/application/device_control_controller.dart` |
| Operation-failed tip UI | `app/lws_hmi/lib/features/process_mode/presentation/operation_failed_dialog.dart` |
| 预检 | `app/lws_hmi/lib/features/process_mode/domain/laser_enable_preflight.dart` |
| 急停 mask | `app/lws_hmi/lib/features/warn_alarm/infrastructure/estop_comm_alarm_mask.dart` |
| 告警适配 | `app/lws_hmi/lib/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart` |
| 拦启用弹窗 | `WarnAlarmController.presentLaserEnableBlock` / `WarnAlarmCoordinator.requestImmediateShow` |
| Android 对照 | `lws-ui` … `EmergencyStopJobHaltPolicy`、`LaserEnableAlarmGuard`、`ModbusFiledConvert.applyEmergencyStopCommAlarmReset` |

Process Mode UI 迁移总览见 [`process-mode-ui-migration-plan.md`](process-mode-ui-migration-plan.md)。
