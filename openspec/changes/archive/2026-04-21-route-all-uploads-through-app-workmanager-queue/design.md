## Context

仓库内 AI 图片上报已经有完整 App 队列链路（`AiUploadCoordinator.enqueue` → `AiUploadDrainWorker` → `DeviceWorkerAiReportClient`），包含本地持久化、WorkManager 调度与失败重试语义。实际联调时仍可能使用 `curl` 或其他直传方式，造成“看起来上传成功，但不触发 App 本地清理/状态迁移”的偏差，影响验收与问题定位。

## Goals / Non-Goals

**Goals:**

- 规范化设备侧上传路径：业务实现与验收都以 App WorkManager 队列为准。
- 对“绕过队列”的路径给出明确边界（允许临时运维工具，但不作为产品行为或测试结论）。
- 统一日志与状态语义，保证“上传成功/重试/清理”可追踪。

**Non-Goals:**

- 不禁止开发者在仓外做独立诊断请求（例如手动 curl）；但该请求不计入 App 规范链路验收。
- 不新增服务端协议字段。
- 不改动 WorkManager 本身重试机制。

## Decisions

1. 规范入口：AI 图片上报 SHALL 通过 `AiUploadCoordinator.enqueue` 入队，实际网络请求 SHALL 由 `AiUploadDrainWorker` 驱动。  
   - 替代方案：允许多入口并行（直传 + 队列）→ 状态分叉，拒绝。

2. 验收策略：与“上传后删除本地源图”等副作用相关的验收，必须通过 App 队列触发；直传仅用于网络可达性排查。  
   - 替代方案：在文档中同时认可直传作为验收 → 结论不一致，拒绝。

3. 可观测性：保留并补充日志 TAG（enqueue、worker drain、post success、cleanup），便于区分“App 队列上传”与“外部直传”。

## Risks / Trade-offs

- [Risk] 调试门槛上升（必须触发 App 代码路径） → Mitigation: 提供最小 debug 入口或测试 hook。
- [Risk] 运维习惯仍用 curl 导致误判 → Mitigation: 文档显式标注“直传不代表 App 队列行为已验证”。
- [Risk] 队列异常时定位链路更长 → Mitigation: 增加关键节点日志和任务目录状态文件检查指引。

## Migration Plan

- 更新文档与 spec 后，后续回归与验收按新规范执行。
- 已有代码以队列为主，无需大规模迁移；重点是约束与验收口径统一。

## Open Questions

- 是否需要提供 UI 上的一键“测试入队上传”按钮作为标准化验证入口（debug build only）。
