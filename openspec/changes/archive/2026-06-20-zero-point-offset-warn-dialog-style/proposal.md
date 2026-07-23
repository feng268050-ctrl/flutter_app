## Why

产线零点偏移提醒当前使用系统 `AlertDialog`（纯文本 + 系统按钮），与摄像头通讯告警等 Modbus/被动告警使用的 `WarnDialog`（`dialog_warn.xml`：警报图标、红色标题、正文滚动区）视觉与交互不一致。操作员难以识别为零点类安全告警，且按钮顺序/样式与产品统一的通讯告警规范不符。需要将零点偏移弹窗对齐摄像头通讯告警样式，并支持「左确认、右跳转」双按钮，跳转一键进入高级设置完成零点校正。

## What Changes

- 扩展共享 `WarnDialog`（`dialog_warn.xml` + `WarnDialogUtil` + `WarnDialogVo`）支持可选**双按钮**底栏：**左侧确认**、**右侧跳转**；单按钮告警（含摄像头通讯 C002）行为保持不变。
- `ZeroPointOffsetWarnAlarm` 从 `AlertDialog` 迁移为 `WarnDialog` 样式：标题/图标/正文与严重通讯告警一致；确认按钮语义与现有告警弹窗相同（关闭弹窗、清除 pending、触发 `onDialogDismissed` / 后续 deferred 队列）。
- **跳转**按钮启动 `DeviceSettingActivity` 并定位到**高级设置** Tab（`TAB_INDEX_ADVANCED_SETTINGS`），供操作员进入零点校正入口。
- 修正现有实现中跳转 Tab 索引错误（当前误用 `0` 设备信息页）。

## Capabilities

### New Capabilities

（无 — 行为在既有 capability 下增量修改。）

### Modified Capabilities

- `production-zero-point-offset-alerts`: 弹窗 UI 与按钮布局、确认/跳转语义、高级设置 Tab 目标。
- `warn-dialog-dual-actions`（delta，若主 spec 不存在则作为 ADDED 写入本 change 的 `specs/warn-dialog-dual-actions/spec.md` 并在归档时合并）：共享 `WarnDialog` 双按钮扩展契约。

## Impact

- **Layout**: `dialog_warn.xml`（双按钮底栏，默认隐藏右侧跳转按钮以保持兼容）。
- **Java**: `WarnDialogVo`, `WarnDialogUtil`, `ZeroPointOffsetWarnAlarm`, `WeldDeferredWarnCoordinator` 集成路径不变。
- **Strings**: 复用 `security_alert_title` / `zero_point_offset_alert_body` / `confirm_text` / `zero_point_offset_alert_go_settings`（或新增「跳转」文案若产品区分「去设置」与「跳转」）。
- **测试**: 零点偏移弹窗 UI 绑定、确认 dismiss、跳转 Intent extra、激光 ON 期间不展示等。
