## Context

高级设置数据 today 集中在 Room 实体 `AdvancedSetting` / 表 `t_advanced_setting`，同时被：

1. **高级设置 UI**（语言、单位、音效、开机自检开关 + 设备参数编辑）
2. **Modbus 设备写入**（0x0090–0x009F 寄存器）
3. **远程快照**（`DeviceRemoteSnapshot.advancedSettings` → JSON `advancedSettings`）

单表混合了「用户偏好」与「设备工艺参数」，且远程协议暴露了全部字段。本次变更在保持 UI 不变的前提下拆分存储，并收窄 WebSocket 暴露面。

当前相关默认值（`DefaultValueUtils.createDefaultAdvancedSetting`）：吹气压力阈值 0；温度阈值等见实体；`showBootSelfCheck` 默认 true；语言初始化取系统 locale 短码（迁移时需映射为 ISO 标签）。

## Goals / Non-Goals

**Goals:**

- 引入 `t_common_settings` + `CommonSettings` 与 `t_parameter_settings` + `ParameterSettings` 及对应 DAO。
- Room 迁移：单行 `t_advanced_setting` → 拆分写入两表；映射 `languageSetting` → `language`（`zh`/`en` 等映射为 `zh-CN`/`en-US`）、`unitSetting`（`true`/null → `metric`，`false` → `imperial`）、`voiceCheck` → `soundEffect`。
- 高级设置页、Modbus 写入、单位/语言/音效/自检逻辑改读新表；`blowPressureThreshold` 校验上限改为 500。
- `command.stat_response` / `device.online` 快照根字段 `commonSettings` 替代 `advancedSettings`；不再序列化设备参数。
- Monitor → Alarm Information 温度读数按 `commonSettings.unit` 做显示转换（与高级设置共用 `TemperatureUnitConvertUtil` 规则）。

**Non-Goals:**

- 高级设置页面布局、文案、控件 ID 变更。
- 新增远程读写设备参数的 WebSocket 命令。
- 修改 Modbus 寄存器地址或写入时序。
- 云端/手机端客户端同步改造（由消费方按破坏性变更自行跟进）。

## Decisions

### 1. 两表各保留单行主记录（`id` 自增，应用始终 `SELECT … LIMIT 1`）

与现有 `t_advanced_setting` 单例模式一致，避免多行歧义。DAO 提供 `selectOne()` / `insert` / `update`，ViewModel 层合并为高级设置 VO 供 UI 绑定。

**备选**：单表加 `category` 列 — 拒绝，无法清晰分离协议与 Modbus 边界。

### 2. `unit` 使用字符串枚举 `imperial` | `metric`（Room `TEXT` + Java enum 或常量）

替代 `unitSetting` 布尔。内部转换层对接 `TemperatureUnitConvertUtil.isMetricUnit`：读取时 `metric` → 原 `true` 语义，`imperial` → 原 `false`。

**备选**：继续用布尔 — 拒绝，与提案及远程 JSON 契约不一致。

### 3. `language` 存完整 ISO 标签；迁移与初始化默认 `en-US`

- 新装 / 缺省：`en-US`
- 迁移：`languageSetting` 为 `zh`/`zh-CN` → `zh-CN`；`en`/`en-US`/null/其他 → `en-US`（未知值保守落默认，可在日志记录）
- UI 仍用现有 Radio/切换逻辑，Fragment 写回时 persist `zh-CN` 或 `en-US`

**备选**：继续存 `getLanguage()` 短码 — 拒绝，不符合 ISO 标签要求。

### 4. 废弃 `AdvancedSetting` 实体与 `t_advanced_setting` 表（迁移后 DROP）

Migration `N → N+1`：

1. `CREATE` 两新表
2. `INSERT` 从 `t_advanced_setting` 拆分（参数列 → `t_parameter_settings`，通用列 → `t_common_settings`）
3. `DROP TABLE t_advanced_setting`

若项目惯例要求保留表名，可留空表 — **本设计选择 DROP** 以消除误用。

### 5. 远程快照：`CommonSettings` 专用 DTO，Gson 字段名 camelCase

`DeviceRemoteSnapshot` / `DeviceInfoVo`：

- 移除 `advancedSettings`
- 新增 `commonSettings`：`{ language, unit, soundEffect, showBootSelfCheck }`
- `unit` 序列化为字符串枚举；`soundEffect` 为整数（0–2，与现 `voiceCheck` 一致）

`DeviceStatusPut` 从新 DAO 组装 `commonSettings`；参数表不参与快照。

### 6. `blowPressureThreshold` 上限 500

仅改 `AdvancedSettingDataCheck.checkGasPressureThreshold` 与关联 string 资源（若 max 文案硬编码 100）。SeekBar/输入对话框范围同步。

### 7. Alarm Information 温度显示

`WarnInfoFragment` 绑定 `DeviceData` 的温度 `*Text` getter（如 `gunMotorTempText`、`environmentTemperatureText`）。实现方案：

- `WarnInfoFragment` 观察 `CommonSettingsDao.selectOneLiveData()`（或共享单位 `LiveData`），将当前 `unit` 注入 binding（如 `binding.setUnitMetric(...)` 或包装 display helper）。
- 扩展 `TemperatureUnitConvertUtil` 支持带一位小数的摄氏 → 华氏格式化（Alarm Information 寄存器温度为 `raw/10`），metric 路径保持 `%.1f ℃`，imperial 路径输出 `%.1f °F`。
- **仅改显示文本**；`fragment_warn_info.xml` 中环境温度告警 checkbox 仍比较 `deviceData.environmentTemperature` 原始摄氏整数，不改阈值逻辑。

### 8. ViewModel 合并策略

`AdvancedSettingViewModel` 保留对外 API（`AdvancedSettingVo`），内部：

- `init`：并行读两表，缺省则 `DefaultValueUtils` 分别初始化并 insert
- `updateDataToDb`：VO → 拆分 entity，分别 update 两 DAO
- 其他模块（Quick Mode 单位）改为观察 `CommonSettingsDao.selectOneLiveData()` 或 ViewModel 暴露的 `LiveData<Boolean>` 适配层

## Risks / Trade-offs

- **[Risk] 远程消费者依赖 `advancedSettings` 设备参数字段** → 文档与 **BREAKING** 标注；参数不再经 stat 暴露，需产品确认无运营依赖。
- **[Risk] 迁移映射语言/单位错误** → 单元测试覆盖典型旧行；未知 `languageSetting` 落 `en-US`。
- **[Risk] 双表更新非原子** → 高级设置保存先写 common 再写 parameter（或同一事务 `@Transaction`）；失败时记录错误，UI 提示与现行为一致。
- **[Risk] `BootSelfCheckSettings` 与 DB 双写** → 统一以 `t_common_settings.showBootSelfCheck` 为权威；`BootSelfCheckSettings` 改为读写 DAO 或委托 ViewModel，去掉独立 SharedPreferences 若存在重复源。

## Migration Plan

1. 合并实现并 bump `AppDatabase` version（当前 43 → 44）。
2. 设备 OTA 升级后首次启动执行 Room Migration；验证高级设置页各字段与 Modbus 写入。
3. 发版说明：WebSocket `advancedSettings` 移除，改用 `commonSettings`。
4. **Rollback**：保留 migration 前 APK 无法回退 DB schema — 标准 Room 不可逆迁移；回滚需清数据或重装。

## Open Questions

- 无阻塞项。`metrics` 用户笔误已规范为 `metric`。
