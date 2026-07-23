## Context

当前用户在手机 App 侧已有扫码或输入设备 SN 的绑定流程，但缺少由设备主动提供的标准化局域网发现入口。为降低手工绑定成本，需要在安卓嵌入式 HMI App 侧提供 mDNS/DNS-SD 服务广播和可连接入口，使手机 App 能在局域网内发现并连接设备。

约束如下：
- 仅面向同一局域网发现，不引入公网发现依赖。
- 兼容 Android 嵌入式系统网络状态变化（Wi-Fi 重连、IP 变化）。
- HMI 侧需持续维护 DNS-SD 广播生命周期并暴露稳定连接入口。
- 文档输出需同时服务手机 App、HMI 端、测试三方。

## Goals / Non-Goals

**Goals:**
- 建立 HMI 设备侧 mDNS/DNS-SD 广播能力，供手机 App 扫描识别。
- 定义手机 App 发现后连接设备的入口契约（地址、端口、协议版本、错误码）。
- 标准化手机 App 对接文档结构：发现契约、连接时序、异常处理、验收清单。
- 明确新能力与现有扫码/SN 绑定的身份语义一致性。

**Non-Goals:**
- 不实现手机 App 侧的扫描 UI/交互逻辑。
- 不替换现有手机 App 扫码/SN 绑定流程。
- 不设计绑定后的云端账号体系改造。
- 不规定底层 mDNS 库具体实现细节。

## Decisions

1. HMI 侧采用 DNS-SD 广播统一服务类型与 TXT 契约  
   - Decision: 约定单一服务类型（例如 `_lws-device._tcp`）和最小 TXT 字段集合（`sn`、`model`、`system_version`、`api_ver`、`connect_proto`）。`model` 与 HMI「设备信息」中的机器型号一致；`system_version` 与已安装 APK 的 `versionName`（界面「系统版本」）一致。  
   - Rationale: 手机 App 只需实现一次发现解析即可适配；字段最小化降低兼容风险。  
   - Alternative considered: 自定义 UDP 广播；被拒绝，因为跨平台解析与维护成本更高。

2. 以 `sn` 作为跨入口统一身份锚点  
   - Decision: HMI 广播中必须提供稳定 `sn`，与扫码/SN 绑定链路可映射到同一 canonical identity。  
   - Rationale: 保证“扫码/SN/局域网发现”三种入口在后端一致归一。  
   - Alternative considered: 使用实例名或 IP 作为身份；被拒绝，因为不稳定。

3. 广播生命周期采用“网络事件驱动重建 + 心跳式续播”  
   - Decision: HMI 在网络可用时发布服务；网络切换/IP 变化时撤销旧服务并重发布；进入不可连接状态时下线广播。  
   - Rationale: 避免手机 App 发现到不可连接的脏实例。  
   - Alternative considered: 静态一次性发布；被拒绝，因为网络变化后信息会失效。

4. 对接文档按“发现 + 连接”双阶段输出并绑定版本  
   - Decision: 文档分为发现契约、连接契约、异常与重试、兼容矩阵四部分，记录 `doc_version`。  
   - Rationale: 手机 App 联调需要明确从“发现”到“连接”的边界与责任。  
   - Alternative considered: 仅提供字段表；被拒绝，因为缺失时序与错误处理语义。

## Risks / Trade-offs

- [广播已发布但连接入口不可用] → 广播状态与连接服务健康检查联动，不健康时下线广播。  
- [字段缺失导致手机 App 无法识别] → 将 `sn`、`api_ver`、`connect_proto` 定义为必填并在发布前校验。  
- [网络切换后发布脏实例] → 网络事件触发撤销并重发布，实例携带启动代次戳。  
- [与扫码/SN 身份不一致] → 增加 identity mapping 校验用例，联调前必须通过。  
- [文档长期失效] → 文档版本纳入发布门禁，协议变更需同步更新。
