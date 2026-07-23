## Why

安全地锁未连通时，激光使能且枪头按下会弹出 Frost 提示并播放告警音。部分现场或调试场景不需要该弹窗干扰操作，但目前无法关闭。需要在通用设置「其他」分组提供显式开关，默认关闭弹窗显示，由操作员按需开启。

## What Changes

- 在 `t_common_settings` 新增布尔字段 `showSafetyGroundLockAlarm`，默认 **false**（不显示安全地锁未连通弹窗）。
- 在通用设置 → 其他（Misc）分组新增开关行「显示安全地锁告警」，与「显示开机自检」并列，切换后立即持久化。
- `SafetyGroundLockPrompt.maybeShow` 在展示弹窗前读取该偏好；为 false 时跳过弹窗与告警音，其余触发条件与自动复位逻辑不变。
- 远程快照 `commonSettings` 增加 `showSafetyGroundLockAlarm` 字段，与本地偏好一致。
- Room 数据库版本递增，为已有设备迁移时新列默认 false。

## Capabilities

### New Capabilities

- `safety-ground-lock-alarm-prompt`: 安全地锁未连通时的 Frost 提示弹窗行为、触发/复位条件，以及受通用设置开关控制的显示策略。

### Modified Capabilities

- `common-settings`: 表结构、默认值、Misc 分组 UI、持久化与远程快照序列化增加 `showSafetyGroundLockAlarm`。

## Impact

- **数据库**：`CommonSettings` 实体、`AppDatabase` 迁移、`DefaultValueUtils.createDefaultCommonSettings()`。
- **设置 UI**：`fragment_common_settings.xml`、`CommonSettingsFragment`。
- **运行时**：`SafetyGroundLockPrompt`；调用方（`GeneralOperationsFragment`、`EngineerModeActivity`、demo trigger）无需改签名，仅在 prompt 内部门禁。
- **远程协议**：`device-remote-snapshot` 中 `commonSettings` JSON 多一字段（经 `common-settings` delta 覆盖）。
- **测试**：`SafetyGroundLockPrompt` 单元测试、`CommonSettings` / 迁移 / 快照序列化相关测试。
