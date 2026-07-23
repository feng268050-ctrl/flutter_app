## Context

（同前。）

## Goals / Non-Goals

**Goals:**

- 统一 proposal 清单 A/B/C/D 类弹窗为 FrostedGlass
- 完整迁移 `GlobalDialogUtil.showStatusDialog`（mode 0–3）
- 删除 E 类历史遗留（含 `BaseDialog` legacy 导入）
- 提取 shared body + wrapper（text、password、picker、status、progress）

**Non-Goals:**

- 不迁移：`ReminderExactDialog`、`EngineerModeEntryTipsDialog`、`CNCExitDialog`、`WorkStatusDialog`
- 不迁移：告警、数字 `InputDialogFragment`

## Decisions

### showStatusDialog → FrostedGlassStatusDialog（D5 + D3）

**决定：** 重构 `GlobalDialogUtil.showStatusDialog` / `updateFirmwareUpgradeProgress` / `closeDialog` 等，内部使用 `FrostedGlassDialog` + `frosted_glass_body_status.xml`（icon + message + 可选 SeekBar + Confirm）。

| mode | FrostedGlass 行为 |
|------|------------------|
| 0 失败 | 错误 icon + message + Confirm |
| 1 成功 | 成功 icon + message + Confirm |
| 2 等待 | 加载 icon + message，`dismissOnScrimClick(true)` |
| 3 阻塞升级 | 加载 icon + SeekBar + message，`dismissOnScrimClick(false)` |

保留现有 public API 与 weak-ref/strong-ref 生命周期，call site 无需改动。

### WorkStatusDialog — 排除

保持现有 `DialogFragment` + 宽屏 `MachineStatusDialogFragment` 宿主，不纳入 FrostedGlass 迁移。

### BaseDialog — 删除

删除 `BaseDialog.java`、`ParameterProcessFragment` 及其专属 adapter/item/layouts、`EngineerModeActivity.parameterImport`。工艺库导入已由其他流程承担。

（其余 decisions：壳层策略、WiFi/password/picker wrapper 等同前。）

## Risks / Trade-offs

- **[Risk] status 弹窗与 FrostedGlass 单 overlay 互斥** → `showStatusDialog` 实现层统一走 FrostedGlass；legacy `createDialogWithLayout` 路径移除后减少双栈
- **[Risk] mode 2 可 scrim 关闭 vs mode 3 不可** → wrapper 按 mode 设置 `dismissOnScrimClick`
- **[Trade-off] `dialog_global.xml` 删除** → 迁移验证通过后再删 layout

## Migration Plan

1. 删除 E 类（含 BaseDialog 链）
2. Shared infrastructure（text、wifi、picker、status/progress body）
3. 迁移 `showStatusDialog` 全 mode（优先，影响面最广）
4. C / A / B 类
5. D1/D2/D4 + QR
6. 清理 legacy layout + 回归

## Open Questions

（无 — G1/G2/G3 已确认。）
