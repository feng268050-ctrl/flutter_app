## Why

高级设置当前将全部字段（通用偏好与设备参数）混在单表 `t_advanced_setting` 中，远程快照通过 `advancedSettings` 暴露整表，导致协议语义不清、字段命名与类型不一致（如 `languageSetting` 存短语言码、`unitSetting` 用布尔表示单位），也不利于后续独立扩展通用设置与设备参数。需要将存储与 WebSocket 载荷拆分，同时保持高级设置页面 UI 与交互不变。

## What Changes

- 新增 Room 表 `t_parameter_settings` 及实体 `ParameterSettings`，承载原 `t_advanced_setting` 中的设备参数类字段（零点校正、摆宽、激光功率、吹气压力阈值、红光偏移、摆速区间、手动送丝/抽丝速度、0x009A–0x009F 温度与气压阈值等）。
- 新增 Room 表 `t_common_settings` 及实体 `CommonSettings`，承载通用偏好字段，使用规范化命名与类型：
  - `language`：ISO 语言标签（现阶段 `zh-CN`、`en-US`，默认 `en-US`，可扩展）
  - `unit`：枚举 `imperial` / `metric`（替代原 `unitSetting` 布尔）
  - `soundEffect`：整数音效选项（替代原 `voiceCheck`）
  - `showBootSelfCheck`：布尔，行为不变
- Room 数据库迁移：从 `t_advanced_setting` 读取现有单行数据，写入新表后废弃旧表列（或删除旧表）；首次启动缺省行时按新默认值初始化。
- 高级设置 ViewModel / DAO / 转换层改为读写两张新表；**UI 布局与控件不变**，仅在数据层做字段映射。
- `blowPressureThreshold` 校验上限由 100 调整为 **500**。
- **BREAKING**：`command.stat_response` `payload.data` 与 `device.online` `payload.stat` 不再包含 `advancedSettings`；改为仅包含 `commonSettings` 对象（上述四个字段）。设备参数不再通过远程快照暴露。
- Monitor → Alarm Information 页面温度读数按 `commonSettings.unit` 转换显示（摄氏/华氏），告警判定仍基于原始摄氏值。

## Capabilities

### New Capabilities

- `common-settings`: 通用设置持久化（`t_common_settings`）、默认值、语言/单位/音效/开机自检开关的读写，以及远程快照 `commonSettings` 序列化。
- `parameter-settings`: 设备参数持久化（`t_parameter_settings`）、从旧表迁移、Modbus 写入与高级设置页参数编辑的数据源。

### Modified Capabilities

- `device-remote-snapshot`: 快照根对象用 `commonSettings` 替换 `advancedSettings`；`commonSettings` 仅含 `language`、`unit`、`soundEffect`、`showBootSelfCheck`。
- `advanced-settings-device-registers`: 持久化目标改为 `t_parameter_settings`；寄存器写入与 UI 行为要求不变。
- `alarm-information-left-panel-layout`: 温度 metric 显示须遵循 `commonSettings.unit`；布局与告警绑定语义不变。

## Impact

- **数据库**：`AppDatabase` 版本递增；新增 `ParameterSettingsDao`、`CommonSettingsDao`；`t_advanced_setting` 迁移后移除或留空壳。
- **实体 / DTO**：`AdvancedSetting` 拆分或废弃；`DeviceRemoteSnapshot`、`DeviceInfoVo` 字段更名；新增 `CommonSettings` 远程序列化类型。
- **设置模块**：`AdvancedSettingViewModel`、`AdvancedSettingConvertUtil`、`AdvancedSettingFragment` 数据绑定层、`BootSelfCheckSettings`、`GlobalSoundManager` 音效读取路径。
- **其他消费者**：`QuickProcessParametersDataViewModel` 等单位读取、`AdvancedSettingDao.selectOneLiveData` 观察者改为 `CommonSettingsDao`；`WarnInfoFragment` / `DeviceData` 温度展示文本。
- **WebSocket / 测试**：`DeviceStatusPut`、`DeviceWebSocketConnectionTest` 及依赖 `advancedSettings` 的文档与断言。
- **远程消费者**：解析 `command.stat_response` / `device.online` 的客户端须改为读取 `commonSettings`（破坏性变更）。
