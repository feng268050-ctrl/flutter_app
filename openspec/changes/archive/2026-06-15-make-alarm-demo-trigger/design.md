## Context

- 告警弹窗由 `WarnAlarmPipeline` → `DeviceDialogHandler` → `AutoDialogQueue` → `WarnDialogUtil` 驱动；活跃 episode 由 `WarnCacheManager` 跟踪；自动关闭由 `DeviceStatusConvert.closeWarn` 处理。
- **`LaserWorkGuard`** 通过 `LaserEnableAlarmGuard.isWorkBlocked` 判断是否 `forceLaserOffForGuardedAlarm`；**当前仅检查 A001/C002/L001**（含危险操作 bypass）。Quick/Engineer 的 `deviceStatusListen` 在每次 Modbus 轮询且激光 ON 时也会调用 `isWorkBlocked`。
- 其余 Modbus 告警（E/H/W 系列等）会弹 passive warn，但**不会**触发运行时关光——这是本次要补的缺口。
- 危险操作开关（`DangerousOperationsSettings`）**仅**对应 A001 气路、C002 相机、L001 镜片污染三种告警的使能豁免，不应扩展到其他码。
- 联调 mock 使用 `BuildConfig.RELEASE_CHANNEL` 门控；演示告警同样门控。

## Goals / Non-Goals

**Goals:**

- **产线**：任意 `AlarmCodeEnums` 异常码的活跃告警 episode，在激光已开启时强制关光；无 bypass 的码一律阻断；A001/C002/L001 在 bypass OFF 时阻断、bypass ON 时不阻断。
- **产线**：告警弹窗展示路径（passive/immediate）在 `errorCode` 非空时调用 `LaserWorkGuard.evaluateAndInterruptIfNeeded` 以实现即时关光，不仅依赖下一次 Modbus 轮询。
- **演示**：`make alarm CODE=…` 触发同上弹窗与关光语义；演示粘性防止 `closeWarn` 自动关弹窗；演示粘性使 `isWorkBlocked` 在底层探测正常时仍视该码活跃（bypass 规则同上）。
- Release channel 忽略演示 broadcast；非法码快速失败。

**Non-Goals:**

- 不中断 **无 `errorCode`** 的 warn 弹窗（通用提示、无码特殊 UI）。
- 不新增第四种危险操作 bypass 开关。
- 不伪造 Modbus 位；`X***` 解除码不演示；无云端 API。

## Decisions

### 1. 触发通道：adb broadcast（演示）

- **Decision**: `make alarm` → `adb shell am broadcast -a com.lasercyber.lws.ui.action.DEMO_ALARM --es code <CODE>`。
- **Rationale**: 与 priv-app / `ensure-adb-ready` 流程一致。

### 2. 演示：`DemoAlarmReceiver` + `DemoAlarmTrigger`

- **Decision**: `DemoAlarmTrigger.handle(code)`：`RELEASE_CHANNEL` 门控 → 解析 `AlarmCodeEnums` → 构造 `WarnDialogVo` → `DemoAlarmStickyTracker.mark` → `WarnCacheManager.putWarn` + `armReminder` → `DeviceDialogHandler.showPassiveWarnDialog` → `LaserWorkGuard.evaluateAndInterruptIfNeeded`。
- **Rationale**: 与产线弹窗/关光共用管线。

### 3. Sticky 不自动关闭（演示）

- **Decision**: `DemoAlarmStickyTracker`；`closeWarn` 对 sticky 码 no-op；操作员关弹窗时 `clear`。
- **Rationale**: 覆盖 Modbus / external cleared 两条自动关闭路径。

### 4. 产线激光中断：扩展 `LaserEnableAlarmGuard.isWorkBlocked`

- **Decision**: `isWorkBlocked(context, deviceStatus)` 返回 true 当且仅当：
  1. **Bypassable trio**（现有逻辑）：`isGasBlocking` / `isCameraBlocking` / `isLensBlocking` — 各含真实故障 **或** `DemoAlarmStickyTracker.isSticky(code)`，且对应 bypass OFF；
  2. **所有其他 `AlarmCodeEnums` 码**：`WarnCacheManager.isWarn(code)` **或** `DemoAlarmStickyTracker.isSticky(code)` — **无 bypass**，一律阻断。
- **Predicate 辅助**：`isBypassableAlarmCode(code)` → A001/C002/L001 only；`isCodedAlarmBlocking(context, code)` 集中判定。
- **Rationale**: `deviceStatusListen` 已轮询 `isWorkBlocked`；扩展后 E006 等 Modbus 告警在 `putWarn` 后下一轮询即关光；与危险操作语义一致（仅 trio 可豁免）。
- **Alternative**: 为每个告警源单独调用 `forceLaserOff` — 否决（分散、bypass 难统一）。

### 5. 产线激光中断：告警展示时即时 `evaluateAndInterruptIfNeeded`

- **Decision**: 在 `DeviceDialogHandler.showPassiveWarnDialog` / `enqueueImmediateWarn` 入口，当 `WarnDialogVo.getErrorCode()` 非空且属于 `AlarmCodeEnums` 时，post 调用 `LaserWorkGuard.evaluateAndInterruptIfNeeded`。
- 保留 `CameraCommunicationAlarmController`、`WeldDeferredWarnCoordinator`、危险操作 toggle OFF 等现有调用点（幂等）。
- **Rationale**: 不等待下一次 `deviceStatusListen` 即可关光。
- **排除**：`errorCode` 为空或不在 `AlarmCodeEnums` 的弹窗不调用。

### 6. Makefile

- **Decision**: `scripts/make/trigger-alarm.sh trigger`；`make alarm CODE=C002`；`ensure-adb-ready` 前置。

### 7. Release 门控（演示）

- **Decision**: `BuildConfig.RELEASE_CHANNEL` 禁用演示 receiver/trigger。产线激光中断增强 **不受** 此门控影响（真实安全行为）。

## Risks / Trade-offs

- **[Risk] `isWorkBlocked` 扩大后 IGNORE 级告警也关光** → 与「所有带码弹窗均中断」产品语义一致；若仅 SERIOUS 应关光需另开需求。
- **[Risk] 演示 sticky 未清除** → dismiss 时 `clear`；文档提醒。
- **[Risk] bypass ON 时演示 A001 不关光** → 符合规格；弹窗仍展示。
- **[Trade-off] broadcast 无 ACK** → Makefile 打印 logcat 提示。

## Migration Plan

1. 扩展 `LaserEnableAlarmGuard` + 告警展示钩子（产线关光）。
2. 实现演示 sticky / trigger / receiver / `closeWarn` 拦截。
3. Makefile + 脚本 + 单元测试 + 手动验证（E006 与 C002 演示）。
4. 无 DB 迁移。

## Open Questions

- 无。
