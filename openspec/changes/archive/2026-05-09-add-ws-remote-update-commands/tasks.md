## 1. WS 命令与 ACK 契约接入

- [x] 1.1 在设备 WS 命令分发中新增 `command.check_update` 处理入口，并接入本地版本检查调用
- [x] 1.2 实现 `command.check_update_ack` 构建与发送，覆盖 `ok/has_update`、manifest（有更新时）和错误字段（失败时）
- [x] 1.3 在设备 WS 命令分发中新增 `command.update_system` 处理入口，并实现“立即返回 ack，不等待升级完成”的行为
- [x] 1.4 实现 `command.update_system_ack` 数据结构与发送逻辑，覆盖 `started=true` 成功路径和 `started=false` 失败路径

## 2. 升级流程编排与并发保护

- [x] 2.1 将远程升级命令与现有 OTA 触发链路打通，确保接受命令后可启动既有升级流程
- [x] 2.2 增加“升级进行中”状态判定，拒绝并发 `command.update_system` 请求并返回可解释错误 ack
- [x] 2.3 补充异常与边界处理（参数非法、检查失败、启动失败、流程中断），保证 ack 和日志语义一致

## 3. 升级进度事件上报

- [x] 3.1 定义 `device.update_progress` 事件映射规则，将本地 OTA 阶段统一映射为对外 stage/progress 语义
- [x] 3.2 在下载、系统升级、完成、失败关键节点发送 `device.update_progress`，保证远端可观测完整生命周期
- [x] 3.3 确保失败/中止路径也发送终态进度事件，避免远端状态卡死在进行中

## 4. 协议对齐与验证

- [x] 4.1 对照 `api-server` 中更新相关 probe/类型定义，逐项校验字段命名、可选字段与错误语义
- [x] 4.2 为新增命令处理和进度上报补充单元测试/集成测试（至少覆盖成功、失败、并发冲突场景）
- [x] 4.3 执行回归验证，确认不影响现有 OTA UI 进度展示与既有 WS 消息处理能力
