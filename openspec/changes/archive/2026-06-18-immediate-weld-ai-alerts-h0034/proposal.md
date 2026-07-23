## Why

产线 L001 镜片重度污染与零点偏移提醒原先设计为「关光后再弹窗」，与 `make alarm CODE=L001` 等即时告警管线冲突，导致出光过程中弹窗被第二次展示逻辑顶掉。零点偏移提醒也没有异常码和告警日志，无法纳入统一的 coded-alarm / `LaserWorkGuard` / 演示触发体系。

## What Changes

- **BREAKING**: 移除 `WeldDeferredWarnCoordinator` 及「激光下降沿后再弹窗」语义；L001 与零点偏移在检测/触发时**立即**走 `DeviceDialogHandler` → `AutoDialogQueue`。
- 零点偏移告警分配异常码 **H0034**，写入 `warn_table`（SERIOUS），弹窗带 `errorCode`，参与 `alarm-laser-interrupt` 运行时关光（无 A001/C002/L001 类 bypass）。
- `LensHeavyContaminationWarnAlarm` 自行订阅 `LensCheckResultEvent`；`ZeroPointOffsetWarnAlarm` 保留 WarnDialog 双按钮（确认 / 去设置）与 `ZeroPointPendingCorrectionStore` 语义。
- 删除 `DeferredExternalWarnAlarm`、`WeldLaserAlertTiming` 及相关测试。

## Capabilities

### New Capabilities

（无 — 行为归入现有 capability 的 requirement 修订。）

### Modified Capabilities

- `production-lens-det-dirty-alerts`: L001 立即弹窗；删除关光延迟与 deferred coordinator 描述。
- `production-zero-point-offset-alerts`: 立即弹窗；新增 H0034、warn_table 日志、AutoDialogQueue 管线。
- `zero-point-detect-on-laser-on`: 偏移超差后即时告警 pending/展示，不再引用关光后展示。
- `ai-vision-lens-dirty-alerts`: 产线 L001 引用改为即时策略；去掉 deferred flow 措辞。
- `lens-stain-temporal-box-reduction`: 产线 L001 不再称 deferred。
- `lens-det-app-inference`: OpenCV 产线 side effect 改为即时 L001 展示策略。

## Impact

- **Java**: `LensHeavyContaminationWarnAlarm`, `ZeroPointOffsetWarnAlarm`, `WarnAlarmPipeline`, `WarnTableViewModel`, `LaserApplication`；删除 `WeldDeferredWarnCoordinator` 等。
- **资源 / 枚举**: `AlarmCodeConstants.ALARM_H0034`, `AlarmCodeEnums.H0034`, `zero_point_offset_alarm_title`。
- **Spec**: 上述 6 个 capability；部分 supersede 未归档的 `zero-point-offset-warn-dialog-style` change 中关于 deferred / 无 warnCode 的描述。
- **无** Modbus、native、云端 API 变更。
