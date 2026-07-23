## Context

`upload.md` 现定义完整设备侧职责：本地任务目录、`metadata.json` / `state.json`、队列 JSON、POST `ai-report`、成功后删除 `yyyy/mm/dd/<model>/tasks/<uuid>/` 并维护 queue。**最新仓库已实现 `ai-report` 客户端与工艺视频 R2 presign 分离**；本设计中的分阶段方案适用于 **补齐本地队列/清理** 或 **老快照对齐**，合并前在最新分支上做一次全文对照即可。

## Goals / Non-Goals

**Goals:**

- 将文档行为映射为可实现的模块边界：网络层、本地存储层、队列调度、与 Lens/Metal 推理触发点集成。
- 明确 `stat` 的构建方式（复用 `DeviceStatusPut.packRemoteSnapshot` 或子集 JSON）。
- 明确 `model` 来源（推理管线当前模型枚举与 `lens`/`metal` 字符串映射）。

**Non-Goals:**

- 不合并工艺视频 R2 presign 上传与 AI 上报为单一路径。
- 不修改 Worker；若接口与文档不一致，以单独联调变更跟踪。

## Decisions

1. **单一权威**：`upload.md` 为接口与目录结构的唯一产品说明；OpenSpec 仅结构化验收条件。

2. **分阶段交付**
   - Phase A：Retrofit/OkHttp `multipart` 最小闭环（无持久队列，内存或单任务）。
   - Phase B：`ai_upload` 目录 + `tasks` + `queue` + 重试。
   - Phase C：清理规则与日期目录收缩（按文档第 9 节）。

3. **`stat` 体积与隐私**：与远程快照一致时需评估字段裁剪；可在 `metadata.json` 与 multipart `stat` 间去重。

## Risks / Trade-offs

- [风险] 本地队列与相机/推理线程并发 — Mitigation：单写者线程或文件锁约定。
- [风险] 占位域名未替换导致联调失败 — Mitigation：`DeviceApiOriginConfig` 或等价统一入口。
- [权衡] Phase A 可快速验证 Worker，但行为与文档 6–9 节不完全一致 — Mitigation：特性开关或文档标注“最小实现”。

## Open Questions（可讨论）

- **域名**：运行时以 **`DeviceApiOriginConfig` 探测并 pin 的基址** 为准（与工艺视频、OTA manifest 一致）；`upload.md` 中 `test.xxx.com` / `prod.xxx.com` 为示例占位。
- `machine_params` 在 `metadata.json` 与 `stat` 是否必须逐字段一致？（仍可与 Worker 联调时定稿。）
- 上传失败重试次数与退避是否由文档补充？（实现侧当前为：失败保留队列首位并停止本轮 drain，需后续重试策略时可再加调度。）
