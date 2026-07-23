## Why

`upload.md` 已更新为 v2 级规格：除原有 R2 路径与 multipart 外，新增 **必填 `model`（`lens` / `metal`）**、**App 私有目录 `files/ai_upload/`**、**任务目录与 queue、metadata.json、上传成功后本地清理** 等。

**仓库状态说明（以最新远端为准）：** 最新代码中 **`POST /v1/devices/:sn/ai-report` 已实现**，与 **工艺视频 R2 presign**（`VideoAndProcessParamsHandler` / `DeviceWorkerPresignedVideoClient`）为 **两条独立链路**；上传链路收尾后即可推送合并。本 OpenSpec 变更创建于 **工作区可能滞后的快照**：若本地无 `ai-report` 引用，请先 `git pull` 再对照本 spec 做验收而非“从零实现”假设。

## What Changes

- 在 OpenSpec 中新增 **App 侧 AI 上报流水线** 能力定义（本地落盘、队列、multipart 字段、清理），与 `upload.md` 对齐。
- 将 **实现缺口清单** 写入任务：HTTP 客户端、目录与 JSON 状态机、与 `DeviceInfo` / `BuildConfig` / `DeviceStatusPut` 的 `stat` 来源衔接。
- 标注 **待与 YOLO/Worker 讨论** 的点：域名占位符 `test.xxx.com`、错误码表、与工艺视频上传（R2 presign）链路的职责边界。

## Capabilities

### New Capabilities

- `ai-report-device-pipeline`: App 侧 AI 检测失败样本的上报流水线（本地 `ai_upload` 目录、任务与 queue、`multipart` 字段 `type`/`image`/`stat`/`model`、成功后的清理与可选归档）。

### Modified Capabilities

- `ai-upload-r2-public-url`: 增量说明 R2 对象键与 `upload.md` 第 5 节一致，**D1 与 `upload.md` 一致** 时包含 `model` 等字段（文档对齐，非运行时 App 行为变更）。

## Impact

- 文档：`upload.md` 为权威来源；本变更的 spec 与之一致。
- 代码：最新分支上 **ai-report 与工艺视频上传并行独立**；收尾工作以 **联调通过、目录/队列/清理与文档一致** 为准，而非重复实现整条 HTTP 客户端（除非快照落后）。
- 协作：Worker 需已支持 `model` 与 D1 字段；合并前确认环境与域名配置。
