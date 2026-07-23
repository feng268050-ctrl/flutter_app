## Why

当前用户在手机 App 侧主要通过扫码或输入设备 SN 进行绑定，流程依赖物理标识与手工操作。为了提升近场发现与连接效率，需要在设备侧（安卓嵌入式 HMI App）提供 mDNS/DNS-SD 广播与连接接入能力，让手机 App 可在局域网自动发现并连接设备，同时保持与现有扫码/SN 绑定体系一致的设备身份语义。

## What Changes

- 新增设备侧 mDNS/DNS-SD 服务广播能力，定义服务类型、实例命名、TXT 元数据字段和版本策略。
- 新增设备侧可连接能力约束，明确手机 App 发现后用于连接/握手的地址、端口、协议入口与错误语义。
- 新增广播生命周期与状态管理要求，包括网络变化、设备状态变化、重复实例冲突处理与离线撤销。
- 新增手机 App 对接文档规范，包含发现契约、连接时序、错误码映射、兼容矩阵与联调验收清单。
- 明确与现有手机 App 扫码/SN 绑定流程的衔接边界，确保局域网发现连接是补充能力而非替代流程。

## Capabilities

### New Capabilities
- `device-mdns-service-advertising`: 定义设备侧（HMI App）如何通过 mDNS/DNS-SD 广播可发现服务及元数据，供手机 App 扫描识别。
- `mobile-device-discovery-integration-docs`: 定义手机 App 对接设备发现与连接能力的文档最小内容、格式与验收标准。

### Modified Capabilities
- None.

## Impact

- Affected specs: `openspec/changes/mdns-dnssd-device-onboarding-docs/specs/device-mdns-service-advertising/spec.md`, `openspec/changes/mdns-dnssd-device-onboarding-docs/specs/mobile-device-discovery-integration-docs/spec.md`
- Affected HMI app modules: 局域网服务广播模块、设备连接接入模块、网络状态监听与服务生命周期管理模块。
- Affected mobile app integration: 手机 App 发现/连接逻辑将对接设备侧 mDNS 广播字段与连接入口定义。
- Affected docs/output: 新增手机 App 对接文档（发现契约/连接流程/错误码/联调清单），供移动端、HMI 端、测试共同使用。
