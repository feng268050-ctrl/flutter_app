## Why

`docs/Automated saving and uploading.md` 定义了镜片污渍检测的审计状态机与自动上传规则，但当前 Live 生产路径上 **检测失败（`DETECT_FAILED`）帧不会自动进入 `ai_upload` 队列**——`AiUploadFailureSampleHook` 仅为调试入口，未与 `OpencvStainDetectCoordinator` / `StreamDetectPipeline` 串联。需要在不重复实现 HTTP 上传基础设施的前提下，先把 **Live weld `lens_det` 检测失败** 自动落盘并走现有 `AiUploadCoordinator` + WorkManager 流水线。

## What Changes

- 新增 **Live 生产 `lens_det` 检测失败自动入队**：当 native 返回 `code == -3`（`DETECT_FAILED`）且 Advanced Settings 镜片污染检测开启时，将对应输入帧与审计 `stat` 写入 `AiUploadCoordinator.enqueue`。
- 定义 **`StainAuditStatus` 与 `stat.json` 审计载荷**（V1 仅使用 `DETECT_FAILED`；`AUTO_SUSPECTED_MISS` / `AUTO_SUSPECTED_FALSE_POSITIVE` / `INTERNAL_FILTERED` 枚举预留，行为在后续迭代实现）。
- **Native 补充失败帧落盘**：在 `analyzeOpencvStainDetectBgr` 的 `kDetectFailed` 路径写入 `input_frame.jpg`（及可解析的 `written_files`），供 Java 入队引用。
- **明确不上传边界**：`code == -5`（`FRAME_REJECTED` / 红帧门控等内部过滤）、`ok == true`、以及 `CLEAN` / `STAIN_CONFIRMED` 业务结果 **不得** 触发 ai-report 入队。
- **复用** 既有 `ai-report-device-pipeline`（`metadata.json` + `stat.json` + WorkManager drain），不引入方案文档中的独立 `task.json` 格式。

## Capabilities

### New Capabilities

- `stain-audit-auto-upload`: Live weld `lens_det` 审计状态、检测失败样本捕获、与 `AiUploadCoordinator` 的自动入队衔接（V1：`DETECT_FAILED` only）。

### Modified Capabilities

- `ai-report-device-pipeline`: `stat.json` 允许（并规范）携带污渍审计字段（`status`、`reason`、`primary_result`、`cluster_*` 等子集；V1 必填子集见 spec）。
- `lens-det-app-inference`: Live weld 路径在 `DETECT_FAILED` 时 SHALL 触发失败样本入队，且 SHALL NOT 在 `FRAME_REJECTED` 时入队。

## Impact

- **Java**: `OpencvStainDetectCoordinator`、新增审计/入队 helper（如 `StainAuditUploader` / `StainAuditStat`）、可能扩展 `AiUploadFailureSampleHook` 为生产路径入口。
- **Native**: `opencv_stain_detect_analyzer`（失败路径写 `input_frame.jpg`）、`summaryToJson` / `written_files` 契约。
- **不上传**: Process Video 离线、`zero_point`、RKNN stain、手动 `AiUploadPictureDirectoryQueue` 调试路径（保持现状）。
- **后续迭代**（本变更 Non-Goal）：`LensStainClusterGuard` 漏检/误检判定、`AUTO_SUSPECTED_*` 入队、定期 15–30 分钟扫描策略（当前 WorkManager drain 已覆盖上传执行）。
