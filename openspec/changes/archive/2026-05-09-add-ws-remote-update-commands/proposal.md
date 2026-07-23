## Why

设备端当前缺少完整的远程更新命令通道，无法通过现有 WS 控制链路实现“检查更新 -> 触发升级 -> 上报升级进度”的闭环。需要与 `api-server` 已定义的消息契约对齐，尽快落地设备可远程升级能力。

## What Changes

- 在设备 WS 消息处理链路新增 `command.check_update` 命令监听，并回传 `command.check_update_ack`（含可选新版本信息）。
- 在设备 WS 消息处理链路新增 `command.update_system` 命令监听，并回传 `command.update_system_ack`，仅反馈“已开始执行”或“启动失败”。
- 在设备执行升级期间持续上报 `device.update_progress`，用于前端/服务端实时展示升级状态。
- 将命令与 ack 的字段命名、错误语义、可选清单数据与 `api-server` 既有结构保持一致，避免协议分叉。

## Capabilities

### New Capabilities
- `device-ws-remote-update-control`: 设备端通过 WS 处理检查更新与触发升级命令，并回传对应 ack。

### Modified Capabilities
- `ota-upgrade-progress`: 扩展升级进度来源，明确 `device.update_progress` 作为远程触发升级过程中的实时进度事件。

## Impact

- 影响模块：设备端 WS 命令分发、OTA 更新触发逻辑、升级进度上报逻辑。
- 影响协议：新增/对齐 `command.check_update`、`command.check_update_ack`、`command.update_system`、`command.update_system_ack`、`device.update_progress`。
- 依赖关系：需与 `api-server` 的消息字段定义保持一致，特别是 `request_id` 关联、`ok/has_update/started` 语义及错误字段。
