## Why

当前 ai-report 上传成功后，只会清理 `files/ai_upload/.../tasks/<uuid>/` 队列副本，不会删除调用方原始图片。对于来源为 `/sdcard/Pictures` 的批量上传场景，用户预期“上传即清理”，否则会持续堆积占用存储。

## What Changes

- 扩展成功上传后的清理策略：在满足受控条件时，允许删除共享外部存储 `Pictures` 目录中的原始图片（不仅限 App 私有目录）。
- 在 `metadata.json` 中持久化原始路径与删除策略标记，保证 WorkManager 跨进程重试后仍可执行删除。
- 增加对共享目录删除失败的可观测日志与不阻塞上传成功的行为约束。
- 更新 `upload.md` 与 `ai-report-device-pipeline` 规格，明确 `/sdcard/Pictures` 删除边界与验收方式。

## Capabilities

### New Capabilities

（无；作为既有 ai-report 设备侧流水线能力的行为增强。）

### Modified Capabilities

- `ai-report-device-pipeline`: 修改“成功上传后本地清理”要求，允许在显式匹配策略下删除 `/sdcard/Pictures` 原图，并定义安全边界与失败处理。

## Impact

- `app/src/main/java/com/lasercyber/lws/ui/ai/upload/`（`AiUploadCoordinator`、`AiUploadMetadata`、源图删除策略类）
- `upload.md`（成功清理与共享目录删除说明）
- 测试：共享目录白名单、误删防护、删除失败可恢复性
