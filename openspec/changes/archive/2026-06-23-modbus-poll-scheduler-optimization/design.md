## Context

当前 Modbus RTU 路径通过 `serialSendExecutor` 单线程串行 I/O，设备状态与数据链式读取，由 `RxTaskManager` 以 200ms Timer 触发。`setSendIntervalTime(200)` 因 `ModbusWorker.doSync()` 公式错误 likely 未生效。`ModbusPollCycleGuard` skip 重叠 tick，但 Timer 与错误间隔叠加仍使有效刷新不可预期。

厂商反馈：**50ms** 命令间隔足够控制板冷却。刷新侧希望更积极（**100ms** 尝试），但**不在总线忙时排队**，以免被动拉大间隔。

## Goals / Non-Goals

**Goals:**

- 任意两条 Modbus 命令之间 enforce 真实 `COMMAND_INTERVAL_MS = 50ms`，锚点为「上一条命令完整结束」。
- 100ms Timer **尝试**启动 poll；总线忙（含上一轮 poll 进行中、其他写/读占用串口队列）则**丢弃**本次 tick。
- OTA、参数写、轮询读共用同一 50ms gate；OTA 期间 **独占** 串口（pause poll + 拒绝非 OTA Modbus）。
- 保留链式读、`RxModbusPollResults`、告警/LED 语义；Mock 跳过 gate sleep。
- Debug 日志：`gateWaitMs`、丢弃 tick 计数、`cycleMs`。

**Non-Goals:**

- 不自调度「整轮结束后再排下一轮」作为主节奏（Timer 100ms + discard 为主）。
- 不改变寄存器映射/UI；不合并状态/数据单次读。
- 不单独缩短 OTA 间隔。
- **不**在新 RTU 路径保留 `DIFF_PROTOCOL_INTERVAL` 或按 Modbus 功能码区分间隔 — 旧自研 `ModbusManager` 的双间隔方案由 `ModbusSerialGate` 完全取代（本 change 不迁移 `ModbusManager` 栈，但不得把 DIFF/SAME 双常量带入 `ModbusManagerRtu`）。

## Decisions

### D1: App 层 `ModbusSerialGate` 为间隔权威（50ms）

**Decision:** `ModbusManagerRtu` 每次 I/O 前 `awaitBeforeCommand()`；`setSendIntervalTime(0)`。

```text
wait = COMMAND_INTERVAL_MS - (now - lastCommandEndMs)
if wait > 0: sleep(wait)
execute command
lastCommandEndMs = now
```

所有 RTU 流量（poll、write、OTA、boot 自检）统一 50ms。

**Supersedes (legacy, not carried forward):**

| 旧机制 | 处置 |
|--------|------|
| `ModbusConfig.SAME_PROTOCOL_INTERVAL` (200ms) | 替换为 `COMMAND_INTERVAL_MS` (50ms) |
| `ModbusConfig.DIFF_PROTOCOL_INTERVAL` (50ms) | **删除/废弃**，不再使用 |
| `ModbusManager.controlProtocolInterval()` | 仅旧栈；RTU 路径不调用 |
| `ModbusWorker.setSendIntervalTime` | 固定为 0 |

### D2: `POLL_TIMER_INTERVAL_MS = 100` 驱动刷新尝试

**Decision:** 替换 `LOOP_DEVICE_STATUS_TIME_INTERVAL`（200ms）为 **100ms** Timer。每 tick 调用 `tryStartPollCycle()`，而非无条件 `run()`。

**Rationale:** 比旧 200ms 更积极；与 50ms 命令间隔解耦——一轮 poll 含 2 条命令 + 1×50ms gate ≈ RTT×2 + 50ms，通常 < 100ms，多数 tick 可启动新轮；忙时丢弃而非堆队。

### D3: 丢弃策略（非排队）

**Decision:** 在 `tryStartPollCycle()` 中，若满足任一条件则**丢弃**本 tick（log debug，立即 return）：

1. **Poll cycle in flight** — 上一轮 status→data 尚未 `finishPollCycle`（保留/重构 `ModbusPollCycleGuard.tryBegin()` 语义，rename 文档为 discard）。
2. **Serial bus busy** — `ModbusSerialGate` 或 `ModbusManagerRtu` 暴露 `isCommandInFlight()`：当前有 Modbus I/O 在执行（含 gate sleep 等待前的 in-flight 标记）。

写指令与 poll 共用 `serialSendExecutor`：写在进行时 poll tick 丢弃，避免 poll 排队拖慢写、也避免写后 poll 被动延迟。

**Alternatives considered:**

- 自调度 only — 刷新上限受 cycle 时长约束，无法 100ms 尝试。
- 排队 poll — 被动拉大间隔（用户明确拒绝）。

### D4: OTA 独占期 — pause poll，禁止其他 Modbus 业务

**Decision:** 控制器 OTA 进行中进入 **`ModbusOtaExclusiveSession`**（或等价 flag）：

1. **Pause** 100ms 常规 status+data poll Timer。
2. **Reject** 一切非 OTA 白名单 Modbus 流量：含参数写、工程师写、boot 自检读、**以及所有 `readInputRegisters`（含 device status）** — 快速失败，不排队。
3. **Allow** 仅 OTA **写**白名单：`writeRegisters` / `writeRegistersCall` 用于升级文件信息、固件数据块、升级结束等。
4. 所有 OTA 写仍经 `ModbusSerialGate`（50ms）。
5. `controllerUpgradeEnd` 清除独占 session，恢复 100ms poll Timer。

**Rationale:** 用户确认 OTA 期间 Modbus 总线完全留给 OTA，**不读 status**；与常规 poll/告警/参数下发隔离。固件块下发规则见 **D5**。

### D5: OTA 固件块 — 顺序写帧 + 50ms 冷却

**Decision:** OTA 独占期内仅 **写** Modbus 帧，不读 status：

1. 下发固件信息写成功后，由 app 维护文件偏移，**顺序**构造各固件数据包写帧（沿用 `ModbusFiledBuilder` / `ControllerUpgradeDataCache` 现有寄存器布局，偏移/长度由 **app 状态** 决定，不再从 `DeviceStatus` 寄存器读取）。
2. 每帧 `writeRegisters` 经 `serialSendExecutor` + `ModbusSerialGate`；**上一帧写完成（含响应）后**，至少等待 `COMMAND_INTERVAL_MS`（50ms），再发下一帧。
3. 末包写完后发升级结束写；成功/失败仍经 `DeviceUpgradeEvent` / `controllerUpgradeEnd` 收束。
4. 不再在 OTA 期间调用 `upgradeHandler` 或恢复常规 poll；`checkControllerUpgradeStatusTask` 仅做超时/stall 看门狗（用 cache/时间戳，无 Modbus 读）。

**Alternatives rejected:** poll 读 status 再写包；OTA 专用更短间隔（用户要求与普通指令相同 50ms）。

**OTA 时序示例：**

```text
write 固件信息 → (50ms) → write 数据帧0 → (50ms) → write 数据帧1 → … → write 升级结束
（全程无 readInputRegisters）
```

### D6: 预期时序（常规 poll）

**Steady state（无其他写、上一轮已结束）：**

```text
Tick @0:   start poll → status RTT → 50ms gate → data RTT → finish (~80–150ms typ.)
Tick @100: if cycle done → new poll; else discard
Tick @200: retry
```

**有效状态刷新**：通常每 **100–200ms**（取决于 cycle 是否能在 100ms 内完成）；比旧 400–600ms 更可预期。

**Under load（频繁写）：** poll tick 丢弃增多，刷新让路给写 — 符合「不排队、不被动拉大写间隔」。

### D7: API / 常量迁移

- `ModbusConfig.COMMAND_INTERVAL_MS = 50`
- `DeviceStatusConstant.POLL_TIMER_INTERVAL_MS = 100`（replace `LOOP_DEVICE_STATUS_TIME_INTERVAL`）
- `recreateDeviceStatusTask(long)` → 使用 `POLL_TIMER_INTERVAL_MS`；deprecated overload 忽略传入 interval 或 warn

### D8: 可观测性

Debug 每 N tick log：`pollDiscarded` reason (`cycle_in_flight` | `bus_busy`), `gateWaitMs`, `cycleMs`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 50ms 对部分批次仍不足 | 常量集中；厂商已确认 |
| 负载高时 poll 丢弃多、Monitor 刷新变慢 | 写完成后再刷新；可接受 vs 排队拉大 |
| 100ms tick + ~100ms cycle 偶发 discard | 下一 tick 100ms 内重试；仍优于旧方案 |
| `isCommandInFlight` 与 gate sleep 边界 | 在 executor 任务入口 set/clear in-flight |

## Migration Plan

1. **Phase 1:** `ModbusSerialGate` 50ms + tests；`setSendIntervalTime(0)`.
2. **Phase 2:** Poll Timer 100ms + `tryStartPollCycle` discard 逻辑；refactor guard/busy check.
3. **Phase 3:** OTA 独占 session（pause poll + reject 非 OTA Modbus）；boot-self-check 走 gate.
4. **Phase 4:** 真机日志验证 discard 率与刷新间隔.

**Rollback:** Revert Phase 2 恢复 200ms Timer + old guard.

## Open Questions

（无 — 均已定案。）

- OTA：pause poll；Modbus **仅写**、**不读** status。
- OTA 分包：顺序 Modbus 写帧，帧间 `COMMAND_INTERVAL_MS`（50ms）。
- `isCommandInFlight` 含 gate sleep：**是**。
