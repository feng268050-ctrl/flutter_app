## Why

`AiUploadCoordinator` 在入队时会把 `imageSource` **复制**到 `files/ai_upload/.../tasks/<uuid>/image.jpg` 再经 WorkManager 上传。Worker 成功后 App 会按现有约定 **删除任务目录**（`tasks/<uuid>/`），但 **调用方传入的原始图片文件**（例如 `getExternalFilesDir(...)/lens_guard/result/` 或 `/sdcard/lws/result/` 下的结果图）往往仍留在磁盘上，形成重复占用，需要人工或额外脚本清理。希望在 **上传成功且已确认云端接受** 后，自动删除这份「已完成」的本地原图（在安全边界内）。

## What Changes

- 在 **成功** 完成 `POST /v1/devices/:sn/ai-report` 且任务从队列移除、`tasks/<uuid>/` 已清理之后，增加 **可选的原始图片删除**：仅当原始路径落在 App 可控目录（例如 `files/`、`cache/`、`Android/data/<pkg>/` 下）且与任务内副本不是同一 inode/路径时执行，避免误删用户相册等任意路径。
- 在 `metadata.json`（或等价 sidecar）中 **持久化原始绝对路径**（或仅持久化「允许删除」标记 + 路径），以便 WorkManager 进程重启后 drain 仍能执行删除。
- 更新 `upload.md` 与 `ai-report-device-pipeline` 规格，使「任务目录清理 + 可选原图清理」可被验收。

## Capabilities

### New Capabilities

（无；行为作为既有流水线的扩展。）

### Modified Capabilities

- `ai-report-device-pipeline`：在「成功上传后本地清理」要求上，补充 **原始 `imageSource` 在满足安全条件时的删除** 及失败时的日志/不重试策略说明。

## Impact

- `app/src/main/java/com/lasercyber/lws/ui/ai/upload/`（`AiUploadCoordinator`、`AiUploadMetadata`、可能的 `AiUploadPaths` / 队列读写）
- `upload.md`（第 6/9 节附近：任务生命周期与清理）
- 单元测试：路径规范化、同文件不删、非白名单路径不删
