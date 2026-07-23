## Why

HMI 弹窗目前混用 `AlertDialog`、独立 `Dialog` 子类、`InputDialogFragment`（自带 BlurView 壳）、`MaterialDialog` 等多种实现，视觉与交互不统一。`FrostedGlassDialog` 已是项目默认 modal 规范（见 `frosted-glass-dialog` spec），但大量 legacy 提示/输入/选择/进度类弹窗仍未迁移，造成设置、网络、监测、升级等页面风格割裂。

## What Changes

- 将**非告警**、**非数字输入**类弹窗，以及用户确认的**进度/状态/自检**类弹窗，统一迁移到 `FrostedGlassDialog` 壳层（简单文案用 `.message(...)`，复杂内容用 `customBodyView` + 薄 wrapper，进度类参考 `ZeroPointAutoProgressDialog` 模式）。
- 为文本输入、日期/时间/时区选择、WiFi 密码、上传进度、固件升级、Boot 自检、QR 展示、全局 status 等场景提供可复用的 frosted-glass body 布局与 feature wrapper。
- 重构 `GlobalDialogUtil` 中仍使用 `createDialogWithLayout` 的提示/确认/升级/status 类方法。
- **删除**历史遗留且已无用的功能：`UploadVideoInput`、状态栏时间快捷设置、`BaseDialog` + legacy 参数工艺导入（`ParameterProcessFragment` 等）。
- 更新相关 OpenSpec delta。

**明确不在本次范围（保持 legacy，不迁移）：**

- 告警类弹窗：`WarnDialogUtil`、`LensDirtyAlertDialogCoordinator`、`ZeroPointOffsetWarnAlarm` 等
- 数字/步进输入：`InputDialogFragment` 中 numeric 类型的全部工程师/高级设置参数弹窗
- 以下确认/提示类弹窗经 review **明确排除**：
  - `ReminderExactDialog`（激光启用「重要提醒」）
  - `EngineerModeEntryTipsDialog`（进入工程师模式首次提示）
  - `CNCExitDialog`（CNC 退出确认）
  - `WorkStatusDialog`（机台状态实时监测面板）

## Dialog inventory（current scope）

### A. 纳入迁移 — 文本/密码输入

| # | 弹窗 | 当前实现 | 入口/文件 |
|---|------|----------|-----------|
| A1 | WiFi 加密网络密码输入 | `AlertDialog` + `dialog_wifi_password.xml` | `WifiActivity.showPasswordDialog` |
| A2 | 工艺参数名称（文本） | `InputDialogFragment`（默认 `TYPE_CLASS_TEXT`） | `InputDialogBuilder.commonlyUsedParameterBuilder` |
| A3 | 焊材名称（文本） | `InputDialogFragment` | `InputDialogBuilder.materialBuilder` |

### B. 纳入迁移 — 日期/时间/时区选择

| # | 弹窗 | 当前实现 | 入口/文件 |
|---|------|----------|-----------|
| B1 | 手动设置日期 | `Dialog` + `dialog_date_picker_custom.xml` | `DateTimeSettingFragment.showDatePicker` |
| B2 | 手动设置时间 | `Dialog` + `dialog_time_picker_custom.xml` | `DateTimeSettingFragment.showTimePicker` |
| B3 | 手动选择时区 | `Dialog` + `dialog_timezone_picker_custom.xml` | `DateTimeSettingFragment.showTimeZonePicker` |

### C. 纳入迁移 — 确认/提示/选择

| # | 弹窗 | 当前实现 | 入口/文件 |
|---|------|----------|-----------|
| C1 | WiFi 忘记网络确认 | `Dialog` + `dialog_wifi_forget_confirm.xml` | `WifiDetailsActivity.showForgetConfirm` |
| C2 | WiFi 初始化引导 | `GlobalDialogUtil.showWifiInitializationDialog` | `dialog_wifi_init_prompt.xml` |
| C3 | 强制断开 WebSocket 提示 | `GlobalDialogUtil.showForcedDisconnectDialog` | `dialog_forced_disconnect_prompt.xml` |
| C4 | 远程锁机通知 | `GlobalDialogUtil.showRemoteLockDialog` | 同上 layout |
| C5 | 运行环境选择 | `GlobalDialogUtil.showSelectAppEnvDialog` | `dialog_select_app_env.xml` |
| C6 | 绑定设备提示 | `GlobalDialogUtil.showBindDeviceDialog` | `dialog_bind_device_prompt.xml` |
| C7 | 设备注册提示 | `GlobalDialogUtil.showDeviceRegistrationDialog` | 同上 layout |
| C11 | 设备信息 QR 码展示 | `AlertDialog` + `dialog_qr_code.xml` | `DeviceInformationFragment` |

### D. 纳入迁移 — 进度/自检/升级/status

| # | 弹窗 | 当前实现 | 入口/文件 |
|---|------|----------|-----------|
| D1 | 工艺视频上传进度 | `VideoUploadProgressDialog` | `ProcessVideoFragment`、`AiVisionVideoChooseActivity`、`CameraController`、`DevActivity` |
| D2 | 内置固件升级确认 | `GlobalDialogUtil.showBundledFirmwareUpgradeDialog` | `BundledFirmwareBootstrap`（首页） |
| D3 | 固件/OTA 升级进行中（mode 3） | `showStatusDialog` + SeekBar | `BundledFirmwareBootstrap`、`updateFirmwareUpgradeProgress` |
| D4 | 开机自检进度 | `BootSelfCheckDialog` | `BootSelfCheckCoordinator` → 首次进入首页 |
| D5 | 全局操作结果/等待（mode 0/1/2） | `GlobalDialogUtil.showStatusDialog` + `dialog_global.xml` | 设备信息检查升级、告警日志清空、Dashboard 保存、`UpgradeActivity` 结果/等待、OSS 失败等 |

`showStatusDialog` 四种 mode 全部纳入；实现上 D3（阻塞进度）与 D5（成功/失败/等待）可共用 FrostedGlass status body wrapper，按 mode 切换 icon / Confirm / SeekBar。

### E. 删除（非迁移）

| # | 功能 | 当前实现 | 处理 |
|---|------|----------|------|
| E1 | 视频上传标题输入 | `UploadVideoInput` + `DevActivity` MaterialDialog | **删除** |
| E2 | 状态栏时间快捷设置 | `TimePickerDialog` + MainActivity dead code | **删除** |
| E3 | Legacy 参数工艺导入 | `BaseDialog` + `ParameterProcessFragment` + adapter/layouts | **删除**（工艺库已改其他导入方式） |

### F. 明确排除（不迁移）

| # | 弹窗 | 原因 |
|---|------|------|
| F1 | `ReminderExactDialog` | 用户 review 排除 |
| F2 | `EngineerModeEntryTipsDialog` | 用户 review 排除 |
| F3 | `CNCExitDialog` | 用户 review 排除 |
| F4 | `WorkStatusDialog` | 用户 review 排除（实时监测面板） |
| F5 | 数字输入 `InputDialogFragment`（~30 项） | 用户指定排除 |
| F6 | 告警 `WarnDialogUtil` 等 | 告警类 |

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `frosted-glass-dialog`: 扩大适用范围；移除 legacy 豁免；补充 status/progress/picker/text-input custom-body 模式
- `wifi-password-connect-dialog`: 密码弹窗壳层改为 FrostedGlass
- `wifi-network-details`: 忘记网络确认改为 FrostedGlass
- `wifi-initialization-onboarding`: WiFi 初始化引导改为 FrostedGlass
- `system-date-time-management`: 日期/时间/时区 picker 改为 FrostedGlass
- `device-remote-lock`: 远程锁机/强制断开改为 FrostedGlass
- `startup-device-user-binding-check`: 绑定/注册设备提示改为 FrostedGlass
- `engineer-mode-common-params`: 工艺参数名/焊材文本输入改为 FrostedGlass
- `monitor-videos-upload-progress-dialog`: 上传进度改为 FrostedGlass
- `startup-bundled-firmware-upgrade`: 确认弹窗与升级进度改为 FrostedGlass
- `boot-self-check`: 自检弹窗改为 FrostedGlass
- `device-identity-qr`: QR 展示弹窗改为 FrostedGlass

## Impact

- **Java**: `GlobalDialogUtil`（含完整 `showStatusDialog`）、`WifiActivity`, `WifiDetailsActivity`, `DateTimeSettingFragment`, `InputDialogBuilder`, `VideoUploadProgressDialog`, `BootSelfCheckDialog`, `BundledFirmwareBootstrap`, `DeviceInformationFragment`, `UpgradeActivity`, `WarnLogFragment`, `DashboardFragment`, `OSSCredentialProviderManger`
- **删除**: `UploadVideoInput`, `TimePickerDialog`, `BaseDialog`, `ParameterProcessFragment`, `ParameterProcessAdapter`, `ParameterProcessItem`, 相关 layout；`EngineerModeActivity.parameterImport`
- **布局**: 新增 `frosted_glass_body_*`；迁移完成后清理 `dialog_global` 等 legacy layout
- **不改动**: `ReminderExactDialog`, `EngineerModeEntryTipsDialog`, `CNCExitDialog`, `WorkStatusDialog`

## Reference — `showStatusDialog` call sites（D5）

| mode | 含义 | 主要位置 |
|------|------|----------|
| 0 | 失败 + Confirm | 设备信息升级检查失败、Dashboard 保存失败、`UpgradeActivity` 各类失败、OSS 网络失败 |
| 1 | 成功 + Confirm | 告警日志清空成功、Dashboard 保存成功、`UpgradeActivity` 升级完成 |
| 2 | 等待/提示，可点外部关闭 | 设备信息升级查询中/已是最新/频率限制、`UpgradeActivity` 升级开始/无更新 |
| 3 | 阻塞 + SeekBar | 内置固件升级进行中（D3，与 D5 同一 API） |

> `WarnDialogUtil.showStatusDialog` 是告警专用，不在本次范围。

## Reference — `WorkStatusDialog`（F4，不迁移）

工程师模式枪头打开自动弹出 / 快速模式点击设备 logo 手动打开的**机台状态实时监测面板**，内嵌 `MachineStatusDialogFragment`。

## Reference — 已删除 `BaseDialog`（E3）

原工程师模式「参数工艺」导入弹窗；工艺库导入已改用其他流程，legacy UI 直接移除。
