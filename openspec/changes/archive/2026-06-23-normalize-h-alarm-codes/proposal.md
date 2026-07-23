## Why

H 系列告警从第 10 个起使用了 **H0010–H0034**（字母 + 4 位数字），与项目其余异常码规范（`E010`、`C001`、`H001` 等 **字母 + 3 位数字**）不一致，也增加了与 `H001`/`H002` 等码混淆、字符串排序错乱的风险。当前尚无出货设备依赖旧码，适合一次性规范化。

## What Changes

- **BREAKING**: 将 `H0010`–`H0034` 重命名为 `H010`–`H034`（25 个码，语义不变）。
- 更新 `AlarmCodeConstants`、`AlarmCodeEnums` 及所有 Java/Kotlin 引用；枚举常量名同步（如 `ALARM_H0010` → `ALARM_H010`，`H0010` → `H010`）。
- 更新 `docs/alarm-codes-reference.md`、OpenSpec 中引用旧码的 requirement（尤其 `H0034` → `H034`）。
- 应用升级时 **不** 做 Room `warn_table` 行级迁移，**不** 在代码里自动清除历史行；旧数据由人工清理（工程师界面或 adb）。
- **不** 引入旧码别名层；`AlarmCodeEnums.findByCode` 仅识别新码。
- **不** 变更 Modbus 位映射、弹窗文案、告警级别或固件协议。

## Capabilities

### New Capabilities

- `alarm-code-naming`: 定义平板应用告警异常码的命名格式（字母 + 3 位数字）及 H010–H034 与旧码对照。

### Modified Capabilities

- `production-zero-point-offset-alerts`: 零点偏移告警码 **H0034** → **H034**。
- `zero-point-detect-on-laser-on`: 引用零点偏移告警码 **H0034** → **H034**。

## Impact

- **Java/Kotlin**: `AlarmCodeConstants`, `AlarmCodeEnums`, `DeviceStatusConvert`, `ZeroPointOffsetWarnAlarm`, `WarnTableViewModel` 等引用 H0010+ 的文件。
- **文档**: `docs/alarm-codes-reference.md`；Makefile / OpenSpec 示例中的 `make alarm CODE=H0034` → `H034`。
- **数据**: 无 App 侧数据迁移；`warn_table` 旧码行由人工清理。
- **无影响**: Modbus 寄存器、固件、WebSocket/SSE 解析逻辑（外部仅展示 `code` 字段）。
