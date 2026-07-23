## Why

设备状态/数据 Modbus 轮询使用 200ms 固定 Timer，同时配置 200ms 串口命令间隔，但 `ModbusWorker.doSync()` 间隔公式错误导致冷却时间很可能未生效；重叠 tick 被 skip 后有效刷新间隔不可预期（常落到 400–600ms+）。厂商确认控制板在命令之间 **50ms** 冷却即可；应改为「单线程排队 + 真实 50ms 间隔 + 100ms 刷新尝试 Timer」，且在总线忙（含上一轮刷新未完成）时**丢弃**本轮刷新 tick，避免排队被动拉大间隔。

## What Changes

- 新增 **`ModbusSerialGate`**：在 `serialSendExecutor` 唯一入口 enforcement「上一条命令完整结束后至少等待 `COMMAND_INTERVAL_MS`（**初值 50ms**）再发下一条」，覆盖读/写/OTA/自检。
- 用单一 **`COMMAND_INTERVAL_MS`（50ms）** 替换旧方案中所有间隔机制：`SAME_PROTOCOL_INTERVAL`、`DIFF_PROTOCOL_INTERVAL`、自研 `ModbusManager.controlProtocolInterval`、`ModbusWorker.setSendIntervalTime` — 新路径不再区分「同/异功能码」间隔；`setSendIntervalTime(0)` 避免与 app 层 gate 重复或错误 sleep。
- **`POLL_TIMER_INTERVAL_MS = 100ms`**：Timer 每 100ms **尝试**启动一轮 poll（读状态 → 读数据）；**不**在总线忙时排队等待。
- **丢弃策略**：若上一轮 poll 仍在进行，或串口上有其他 Modbus 指令（写参数、OTA 等）正在执行/排队，则**丢弃**本次 Timer tick，下一 tick 再试。
- OTA 与轮询、写参数**共用** `COMMAND_INTERVAL_MS`（50ms），**无**独立 upgrade profile。
- **OTA 独占期**：pause 100ms poll Timer；串口**仅允许** OTA 相关 Modbus **写**（文件信息、固件块、升级结束等）；**禁止任何 Modbus 读**（含 device status）；参数写、常规 poll 等**拒绝或快速失败**，直至 `controllerUpgradeEnd`。
- Mock 路径跳过 gate sleep；debug 日志记录 gate 等待、丢弃 tick、cycle 耗时。
- **BREAKING（内部）**：`LOOP_DEVICE_STATUS_TIME_INTERVAL`（200ms）改为 `POLL_TIMER_INTERVAL_MS`（100ms）；`recreateDeviceStatusTask(long)` 的 interval 参数语义变更或 deprecated。

## Capabilities

### New Capabilities

- `modbus-poll-scheduler`: Modbus 串口 50ms 命令冷却、100ms 刷新 Timer、总线忙时丢弃 tick、OTA 同策略、可观测性与 mock 豁免。

### Modified Capabilities

- `boot-self-check`: 同步 Modbus 快照读 MUST 经同一 `ModbusSerialGate`（50ms），与运行时一致。

## Impact

- **Java**: `ModbusManagerRtu`, `ModbusConfig`, `ModbusOtaExclusiveSession`, `DeviceStatusConstant`, `DeviceStatusTaskHandler`, `ControllerUpgradeHandler`（OTA 独占、不再 restore 常规 poll）, `BootSelfCheckEvaluator`.
- **测试**: gate 单元测试；poll discard-on-busy 单元测试。
- **配置**: `COMMAND_INTERVAL_MS=50`, `POLL_TIMER_INTERVAL_MS=100`。
- **OTA 行为变更**: 固件块改为顺序 Modbus 写帧 + 50ms 冷却，不再通过 poll 读 status 触发 `upgradeHandler`。
- **无** UI、云端 API、native AI 变更。
