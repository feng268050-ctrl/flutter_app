## Context

`SafetyGroundLockPrompt` 在激光使能、枪头按下且安全地锁未连通（`DeviceStatus.isSafetyGroundLockLocked()` 为 false）时，通过 `FrostPromptDialog` 展示「安全地锁未连通」提示并播放 `GlobalSoundManager.warnSound()`。该提示不是告警日志条目，按单次枪头按下只弹一次，激光使能关闭、枪头释放或地锁导通时自动复位。

通用偏好已集中在 `t_common_settings`（`CommonSettings`），Misc 分组已有「显示开机自检」开关（`showBootSelfCheck`，默认 true），由 `BootSelfCheckSettings` 提供带内存缓存的读取。本次在相同分组新增「显示安全地锁告警」，默认 **false**。

调用 `SafetyGroundLockPrompt.maybeShow` 的位置：`GeneralOperationsFragment`、`EngineerModeActivity`、`DemoSafetyGroundLockTrigger`（adb 调试）。

## Goals / Non-Goals

**Goals:**

- 在通用设置 Misc 提供「显示安全地锁告警」开关，默认关闭。
- 关闭时抑制安全地锁未连通 Frost 弹窗与告警音；开启时保持现有行为。
- 偏好持久化于 `t_common_settings`，并纳入远程 `commonSettings` 快照。
- 数据库迁移对已有设备默认 false，不改变 RGB 就绪灯等其他地锁相关逻辑。

**Non-Goals:**

- 不修改 Modbus 地锁状态读取、Monitor 告警列表或 RGB LED 就绪判定。
- 不改变 `DemoSafetyGroundLockTrigger` adb 入口的可见性（调试仍可调 `maybeShow`，但受同一偏好门禁）。
- 不提供「本次会话不再提示」——与开机自检不同，这是全局持久开关。

## Decisions

### 1. 存储字段：`showSafetyGroundLockAlarm`（默认 false）

与 `showBootSelfCheck` 并列放在 `CommonSettings`，Room `@ColumnInfo(defaultValue = "0")`。新装与迁移缺省均为 false，满足「默认不开启」。

**备选**：SharedPreferences 独立存储 —— 拒绝，无法进入 `commonSettings` 远程快照，且与通用设置分组语义不符。

### 2. 读取路径：轻量 helper `SafetyGroundLockAlarmSettings`

仿 `BootSelfCheckSettings` 提供 `isEnabled(Context)` 与测试 override，但**不**做进程级 warm cache（弹窗触发频率低，且 `maybeShow` 已在 Modbus 回调路径；直接读 DB 或短缓存即可）。实现上可用单次 volatile 缓存 + 后台刷新，或每次 `maybeShow` 前同步读一行——优先简单：与 `BootSelfCheckSettings` 同构的缓存，避免主线程阻塞。

`SafetyGroundLockPrompt.maybeShow` 在通过现有触发条件后、设置 `promptedForCurrentGunPress` 之前检查 `isEnabled`；为 false 时直接 return，不播放声音、不展示对话框。

### 3. UI：Misc 第二行 FrostSwitch

在 `fragment_common_settings.xml` 的 Misc `InsetList` 中于开机自检行下追加一行，字符串资源 `common_settings_show_safety_ground_lock_alarm`（中文「显示安全地锁告警」，英文 "Show Safety Interlock Alarm"）。`CommonSettingsFragment` 绑定与 `bindBootSelfCheck` 对称。

### 4. 数据库迁移 `Migration_49_50`

`ALTER TABLE t_common_settings ADD COLUMN showSafetyGroundLockAlarm INTEGER NOT NULL DEFAULT 0`。`AppDatabase.version` 49 → 50。

### 5. 远程快照

扩展 `common-settings` 规范：`commonSettings` JSON 增加 `showSafetyGroundLockAlarm`（boolean）。`DeviceRemoteSnapshotTest` 等断言同步更新。

## Risks / Trade-offs

- **[Risk] 操作员关闭开关后忘记地锁未接** → 开关文案明确为「显示…告警」；RGB 绿灯就绪与其它互锁逻辑不受影响，仅去掉弹窗/声音。
- **[Risk] 主线程读 DB** → 使用与 `BootSelfCheckSettings` 相同的后台缓存模式，避免在 UI/Modbus 线程阻塞。
- **[Risk] 已显示中的弹窗在设置关闭后仍停留** → 可接受；用户关闭开关后下次触发才生效。若需即时 dismiss 可作为后续增强，本次不实现。

## Migration Plan

1. 发布含 `Migration_49_50` 的版本；升级后既有设备 `showSafetyGroundLockAlarm = false`，弹窗默认不出现。
2. 需要弹窗的现场在通用设置手动开启。
3. 回滚：降级 APK 时 Room 不降级；字段仅在新版本读取，旧版忽略该列（SQLite 允许）。

## Open Questions

无。需求明确：Misc 开关、默认关、仅控制 `SafetyGroundLockPrompt` 弹窗显示。
