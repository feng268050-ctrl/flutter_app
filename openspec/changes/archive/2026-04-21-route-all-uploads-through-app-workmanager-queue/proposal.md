## Why

当前联调与排障中，存在直接 `curl` 或其他绕过 App 队列的上传方式，导致行为与产品路径不一致（如本地清理、重试策略、SN 来源、日志追踪都不统一）。需要明确“后续上传统一走 App WorkManager 队列”，保证可观测性与一致性。

## What Changes

- 明确 AI 图片上传的规范入口为 `AiUploadCoordinator.enqueue(...)` + `AiUploadDrainWorker`，禁止新增绕过队列的直传实现作为业务路径。
- 收敛上传行为：SN 获取、元数据构建、重试、成功后清理都由队列链路统一执行。
- 为开发/测试场景提供“通过 App 队列触发上传”的调试入口说明，替代 `curl` 作为验收主路径。

## Capabilities

### New Capabilities

（无；属于既有 ai-report 设备侧流水线的约束增强。）

### Modified Capabilities

- `ai-report-device-pipeline`: 修改为“设备侧 AI 图片上传 SHALL 通过 App WorkManager 队列执行”，并补充禁止绕过队列作为规范实现路径。

## Impact

- `app/src/main/java/com/lasercyber/lws/ui/ai/upload/`（协调器、Worker、触发入口）
- 可能影响调试入口（如 sample hook / debug action）
- `upload.md`（手动验证方式与推荐路径）
