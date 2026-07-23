## Context

`AlarmCodeConstants` / `AlarmCodeEnums` 中 H 系列第 1–9 个为 `H001`–`H009`（3 位），第 10–34 个误写为 `H0010`–`H0034`（4 位）。告警码由 App 根据 Modbus 布尔位分配，固件不下发字符串。用户确认：无需 Room 行级迁移、无需 App 启动清表（人工清理）、无需兼容外部 SSE 解析、无出货售后约束。

## Goals / Non-Goals

**Goals:**

- 将 25 个 H 码统一为 `H010`–`H034`。
- 保持每个码对应的标题、内容、运行时级别、Modbus 映射不变。
- 同步文档与 OpenSpec。

**Non-Goals:**

- App 启动时或后台任务自动删除/改写 `warn_table` 旧码行（由人工清理）。
- Room migration 将 `H0010` UPDATE 为 `H010`。
- 旧码别名 / `findByCode` 双轨。
- 重命名 E/X/C 等其他系列。
- 修改告警弹窗或队列行为。

## Decisions

### 1. 一对一重命名表（语义不变）

| 旧码 | 新码 | 旧码 | 新码 |
|------|------|------|------|
| H0010 | H010 | H0022 | H022 |
| H0011 | H011 | H0023 | H023 |
| H0012 | H012 | H0024 | H024 |
| H0013 | H013 | H0025 | H025 |
| H0014 | H014 | H0026 | H026 |
| H0015 | H015 | H0027 | H027 |
| H0016 | H016 | H0028 | H028 |
| H0017 | H017 | H0029 | H029 |
| H0018 | H018 | H0030 | H030 |
| H0019 | H019 | H0031 | H031 |
| H0020 | H020 | H0032 | H032 |
| H0021 | H021 | H0033 | H033 |
| | | H0034 | H034 |

**Rationale**: 与 `E010`、`X010` 等项目惯例一致；`H010` 不与 `H001`–`H009` 冲突。

### 2. 历史数据：人工清理，App 不介入

不在代码里做 `warn_table` 清理或 Room migration。升级前/后由操作员通过告警列表清空功能或 adb 删除旧行。

遗留的 `H0010`–`H0034` 行在告警列表中可能显示默认文案（`findTitleId` 找不到枚举），直到人工清表。

**Alternatives considered**: 启动时 `DELETE` 旧码行 — 用户选择人工处理，不写入 App。

### 3. 无旧码兼容层

`AlarmCodeEnums.findByCode("H0022")` 返回 `null`；`make alarm CODE=H0022` 失败并打日志。

**Rationale**: 无出货设备；别名增加长期技术债。

### 4. 常量与枚举命名

- String 常量：`ALARM_H010 = "H010"`（非 `ALARM_H0010`）。
- 枚举成员：`H010`（非 `H0010`）。
- 机械替换 `DeviceStatusConvert` 等处的 `AlarmCodeEnums.H0010` → `H010`。

### 5. 文档与演示

- `docs/alarm-codes-reference.md` 全表更新。
- OpenSpec / Makefile 示例 `H0034` → `H034`。

## Risks / Trade-offs

- **[Risk] 开发/测试环境 `warn_table` 仍有旧码** → 人工清表；旧行可能显示默认标题，可接受。
- **[Risk] 遗漏硬编码字符串** → `rg 'H00(1[0-9]|2[0-9]|3[0-4])'` 全库扫描 + 编译。
- **[Trade-off] 破坏性改名** → 用户已确认无售后/外部解析需求，可接受。

## Migration Plan

1. 改常量、枚举、引用、文档。
2. 人工清空 `warn_table`（如需）。
3. 手动：`make alarm CODE=H022`、`H034` 弹窗；Modbus 模拟激光器通信位 → 日志/弹窗显示 `H022`。
4. 归档 change 后合并 delta spec 入主 spec。

## Open Questions

（无 — 用户已明确范围。）
