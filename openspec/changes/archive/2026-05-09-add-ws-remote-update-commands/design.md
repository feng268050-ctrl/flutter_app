## Context

当前设备端已有 WebSocket 统一信封与部分命令处理能力，但缺少面向远程更新的标准命令接入。`api-server` 已在设备协调层约定了以下协议语义：设备需处理 `command.check_update` 和 `command.update_system`，并返回对应 ack；升级过程通过 `device.update_progress` 持续上报。  
本次设计目标是在不破坏现有 OTA 实现的前提下，将远程更新控制接入现有 WS 命令通道，并保持字段与语义与服务端一致。

## Goals / Non-Goals

**Goals:**
- 支持监听 `command.check_update`，触发本地检查并回传 `command.check_update_ack`。
- 支持监听 `command.update_system`，触发升级启动并回传 `command.update_system_ack`（仅表示“已开始/启动失败”）。
- 在升级执行阶段持续发送 `device.update_progress`，用于上游实时展示状态。
- 所有新增消息字段采用 snake_case，并保留 `request_id` 关联能力。

**Non-Goals:**
- 不重构现有 OTA 核心下载/安装实现，只做命令编排与状态桥接。
- 不定义服务端 HTTP API 行为，仅确保设备端 WS 契约可被现有服务端消费。
- 不在 ack 中等待完整升级结束结果（升级最终结果通过进度事件和后续状态体现）。

## Decisions

1. **以现有 WS 命令分发入口扩展远程更新命令处理**
   - 在当前 `type` 分发中新增两个命令分支，避免另起并行通道。
   - 好处是复用现有 envelope 校验、request id 透传和错误处理路径。
   - 备选方案是在 OTA 模块中直接监听底层 socket；该方案会造成协议层与业务层耦合，最终不采用。

2. **ack 与进度上报职责分离**
   - `command.update_system_ack` 仅反馈命令是否已成功进入执行流程（例如 started=true）或启动失败（ok=false + error）。
   - 升级过程与结果通过 `device.update_progress` 按阶段推送，不阻塞 ack 返回。
   - 该选择与服务端等待模型一致，可避免请求超时和误判“升级失败”。

3. **更新检查结果按“有无更新 + 可选 manifest”表达**
   - `command.check_update_ack` 至少包含 `ok` 与 `has_update`。
   - 当 `has_update=true` 时附带版本清单字段（如版本号、包名、发布时间、校验和、下载地址）；当检查失败时返回错误码与错误信息。
   - 备选方案仅返回布尔值，信息不足以支撑后续启动升级，故不采用。

4. **统一进度事件结构并兼容异常路径**
   - `device.update_progress` 采用稳定字段（阶段、进度百分比、可选错误信息）。
   - 对于失败或中止路径，同样发送终态事件，避免前端卡在“升级中”。
   - 备选方案只在成功路径发送进度，风险是用户侧状态不一致，故不采用。

## Risks / Trade-offs

- **[Risk] 协议字段与 `api-server` 漂移** → 在实现阶段复用同名字段并补充契约测试/示例。
- **[Risk] 设备并发触发多个升级命令导致状态冲突** → 增加“升级进行中”判定，重复命令返回可解释错误。
- **[Risk] 本地升级流程阶段与进度映射不稳定** → 定义固定阶段映射表并将未知阶段降级为通用状态。
- **[Trade-off] ack 不等待完整升级结果** → 降低请求时延与超时风险，但调用方需消费进度事件获取完整过程。
