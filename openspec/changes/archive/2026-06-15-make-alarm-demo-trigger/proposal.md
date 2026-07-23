## Why

演示和联调告警弹窗时，目前只能依赖真实设备故障或通讯异常（例如 C002 相机 ping 不通）。通讯类告警在探测恢复正常后会立刻走 `closeWarn` 自动关弹窗，演示人员来不及看清 UI。需要一条可重复的本地命令，按异常码手动弹出对应告警，且弹窗保持到操作员手动确认。

同时，产线 **`LaserWorkGuard` 目前仅对 A001/C002/L001 做运行时关光**，其余带异常码的告警（如 E006、H008）弹出 warn 弹窗时并不会强制中断已开启的激光。产品语义应为：**所有带 `AlarmCodeEnums` 异常码的告警弹窗均须中断激光**；**仅 A001、C002、L001 三种**可通过 Advanced Settings 危险操作开关在告警仍活跃时继续使能/出光。

## What Changes

- 新增 **`make alarm CODE=<code>`** Make 目标：通过 adb 向已连接设备上的 LWS UI 发送演示告警触发请求（例如 `make alarm CODE=C002`）。
- 新增应用内 **演示告警触发入口**（adb broadcast）：根据 `AlarmCodeEnums` 解析异常码，走现有 `WarnDialogVo` / `AutoDialogQueue` 弹窗管线展示标题与文案。
- 演示触发的告警 episode **不得**因底层通讯/Modbus 探测恢复正常而自动 `closeWarn`；仅操作员关闭弹窗后解除演示粘性。
- **补全产线告警激光中断**：扩展 `LaserEnableAlarmGuard.isWorkBlocked` 与告警管线，使所有带异常码的活跃告警在激光已开启时强制关光；**无异常码**的特殊 warn 弹窗不在此列。
- **危险操作 bypass 范围不变**：仅 A001/C002/L001 在对应开关 ON 时可不阻断使能/出光；其余异常码 **无** bypass，告警活跃即中断。
- 演示触发与产线告警共用同一 `LaserWorkGuard` / `isWorkBlocked` 规则；演示粘性在底层探测正常时仍视为该码活跃。
- 在 **`BuildConfig.RELEASE_CHANNEL == true`** 的产线构建中完全禁用演示触发。
- `make help` 与 `scripts/make/` 文档化用法与示例。

## Capabilities

### New Capabilities

- `make-alarm-demo-trigger`: `make alarm` 目标、adb 触发协议、演示告警弹窗行为（含 sticky 不自动关闭）及 release 门控。
- `alarm-laser-interrupt`: 所有带异常码告警弹窗的运行时激光中断规则，及仅 A001/C002/L001 可 bypass 的边界。

### Modified Capabilities

- `build-ci-tooling`: Makefile 要求扩展，包含 `make alarm CODE=…` 目标与 help 文案。
- `advanced-settings-dangerous-operations`: 明确危险操作开关 **仅** 豁免 A001/C002/L001，不豁免其他异常码告警的激光中断。

## Impact

- **Makefile** / `scripts/make/trigger-alarm.sh`：新 target、`.PHONY`、help 段落。
- **Android app**：`LaserEnableAlarmGuard`、`LaserWorkGuard`、`WarnAlarmPipeline` / `DeviceDialogHandler`；演示组件 `DemoAlarmStickyTracker`、`DemoAlarmTrigger`、Receiver；`DeviceStatusConvert.closeWarn` 演示粘性拦截。
- **文档**：`docs/alarm-codes-reference.md` 或 Makefile help 中补充演示命令与激光中断语义。
- **无** Modbus、OTA、云端 API 变更；产线 release 包行为增强（更多告警会关光），演示触发仍禁用。
