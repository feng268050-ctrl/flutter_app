## Context

- 产线 weld AI 告警原先经 `WeldDeferredWarnCoordinator` 监听 `DeviceStatus` 激光下降沿，再 drain `DeferredExternalWarnAlarm.tryShowDialog()`；L001 在 `tryShowDialog` 内断言 `!isLaserOn()`。
- 演示告警 `DemoAlarmTrigger` 与 Modbus passive warn 走 `DeviceDialogHandler.showPassiveWarnDialog`，在出光中即可展示并触发 `LaserWorkGuard`。
- 同一 L001 码两条路径并存时，关光下降沿会用 `enqueueImmediateWarn(REPLACE_PENDING)` 替换已显示弹窗，表现为「一闪即关」。
- 零点偏移原先无 `errorCode`、无 `warn_table` 行，不参与 `AlarmCodeEnums` / demo alarm / `isOtherCodedWarnBlocking`。

## Goals / Non-Goals

**Goals:**

- L001、H0034 在 fault 成立且 `WeldAlertScope` 允许时**立即**弹窗。
- H0034 使用与 Modbus/C002 相同的 passive warn 缓存与队列；写入 SERIOUS 告警日志。
- 删除 deferred coordinator 及接口，降低与 demo alarm 的冲突面。
- 保留：L001 laser-enable 阻断、`allowWorkAfterLensContamination` bypass、零点双按钮与跳转高级设置、`ZeroPointPendingCorrectionStore` 在「去设置」路径不清除。

**Non-Goals:**

- 不改变零点 native 采样、cluster reducer、0090H 写入逻辑。
- 不改变 AI Vision 页 `LensDirtyAlertDialogCoordinator`（非产线 L001）。
- 不新增 H0034 的危险操作 bypass（仍仅 A001/C002/L001 可豁免）。

## Decisions

### 1. 删除 `WeldDeferredWarnCoordinator`

- **Decision**: EventBus `LensCheckResultEvent` 改由 `LensHeavyContaminationWarnAlarm.start/stop` 注册；激光下降沿不再 drain 弹窗队列。
- **Rationale**: 延迟展示是冲突根因；即时展示与 `alarm-laser-interrupt` 产品语义一致。

### 2. L001 即时 passive warn

- **Decision**: `handleLensCheckResult` 在 heavy 时 `saveLensHeavyContaminationWarnLog` + `WarnCacheManager` + `DeviceDialogHandler.showPassiveWarnDialog`，`errorCode=L001`。
- **Rationale**: 与 demo alarm、Modbus 告警共用 `AutoDialogQueue`（`SKIP_IF_PENDING` 同码去重）。

### 3. H0034 零点偏移

- **Decision**: 新增 `AlarmCodeConstants.ALARM_H0034` / `AlarmCodeEnums.H0034`；`saveZeroPointOffsetWarnLog`；弹窗 `errorCode=H0034`，标题 `zero_point_offset_alarm_title`。
- **Rationale**: 纳入 coded-alarm 体系；告警监视器可检索；`make alarm CODE=H0034` 可演示。

### 4. 零点弹窗仍用 WarnDialog 双按钮

- **Decision**: `WarnDialogVo` 保留 `jumpButtonText` / `onJump`；经 `AutoDialogQueue` 的 `openDialog` 展示，不再直接 `WarnDialogUtil.openDialog` 绕开队列。
- **Rationale**: 与 `zero-point-offset-warn-dialog-style` 已实现的 UI 一致，同时获得 errorCode 与关光中断。

### 5. 功能开关 OFF 时的收尾

- **Decision**: `AiAssistanceSettings` 在关闭对应 toggle 时仍调用 `onFaultCleared()`（清 pending、`closeWarn`、episode tracker）；适用于「先告警再关开关」的过渡态。
- **Rationale**: 避免关功能后仍留 H0034/L001 活跃缓存；不删除已写 warn_table 历史行。

## Risks / Trade-offs

- **[Risk] 出光中弹窗打断作业** → 与「所有带码告警可关光」及 demo 行为一致；仅 trio + `keepLaserOnWhileAlarmed` 可豁免。
- **[Risk] 与 `zero-point-offset-warn-dialog-style` change 重复** → 本 change supersede 其 deferred / 无 warnCode 部分；WarnDialog 样式部分已在代码中落地。

## Migration Plan

1. 删除 coordinator + deferred 接口；L001/H0034 改即时路径（已完成）。
2. 更新 OpenSpec delta 并 sync 至 `openspec/specs/`。
3. 手动：`make alarm CODE=L001` / `H0034` 出光中弹窗保持；告警列表见 H0034 行。
