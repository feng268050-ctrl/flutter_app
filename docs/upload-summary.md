# AI 检测样本上传链路（摘要）

> 原文：[`../upload.md`](../upload.md)  
> 更新：2026-05-15

## 一句话

设备将 **AI 检测失败样本**（图片 + 可选设备状态）通过 `POST /v1/devices/:sn/ai-report` 上报云端；App 用 **WorkManager 单图队列**，成功后删本地源图。

## 接口约定

| 字段 | 说明 |
|------|------|
| `type` | 当前仅 **0** = 检测失败 |
| `model` | `lens` / `metal` |
| `image` | 必填，当前推理帧 |
| `stat` | 可选 JSON，与 `device.online` 结构一致 |

环境按 `BuildConfig.RELEASE_CHANNEL` 选 test/prod 域名。

## R2 对象键（Worker 生成）

```text
uploads/ai/{staging|release}/{type}/{yyyy-mm-dd}/{sn}/{uuid}.{ext}
```

`stat` 写入 D1 `ai_reports`，不入 R2。

## App 链路

1. 确定 `sn`、`model`、`type`、`image`，可选 `stat`
2. 一张图一个 `OneTimeWorkRequest` → `AiUploadSingleImageWorker`
3. multipart 上传；**成功删源图**，失败 `Result.retry()`
4. 私有目录任务流：`files/ai_upload/yyyy/mm/dd/<model>/tasks/<uuid>/`

批量入队：`AiUploadPictureDirectoryQueue.enqueueDefaultPicturesToTestWorker`

**App 不负责**：拼 R2 key、写 R2/D1。

## 验收

以 **WorkManager + instrumentation** 为准，`curl` 仅作连通性诊断。

通过标准：每张图独立 work；日志含 `single image work upload start` / `success and delete requested`；成功则源图删除。

## 错误码（摘要）

| code | 含义 |
|------|------|
| 0 | 成功 |
| 4001–4008 | 参数校验 |
| 5001–5003 | R2 / D1 / 内部错误 |

## 详细规格

OpenSpec：`ai-report-device-pipeline`、`ai-upload-r2-public-url`（`openspec/specs/`）
