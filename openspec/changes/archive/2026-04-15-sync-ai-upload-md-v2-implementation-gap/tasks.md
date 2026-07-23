## 1. Spec and gap analysis

- [x] 1.1 Re-read `upload.md` and confirm no drift from `openspec/specs/ai-upload-r2-public-url/spec.md` for R2 key shape.
- [x] 1.2 On **latest** branch: locate existing `ai-report` implementation and map classes to this spec (skip “greenfield” list if already merged). → 见 `IMPLEMENTATION_MAP.md`
- [x] 1.3 Resolve open questions in `design.md` with Worker owner (domain names, error codes). → 运行时域名以 `DeviceApiOriginConfig` 为准；其余见 `design.md` 更新段

## 2. Minimal HTTP implementation (Phase A)

- [x] 2.1 Add Retrofit/OkHttp service for `POST .../ai-report` with `type`, `image`, `model`, optional `stat`. → `DeviceWorkerAiReportClient`（OkHttp multipart，与 presign 客户端同模式）
- [x] 2.2 Wire `DeviceApiOriginConfig` (or project equivalent) for staging vs release base URL. → 使用 `getPinnedBase()` + `joinUnderBase` + path `v1/devices/{sn}/ai-report`
- [x] 2.3 Unit test multipart part names and presence of `model`. → `DeviceWorkerAiReportMultipartTest`

## 3. Local pipeline (Phase B–C)

- [x] 3.1 Implement `files/ai_upload/` directory tree per section 6 with `tasks/<uuid>/` and queue files. → `AiUploadPaths`, `AiUploadQueueJson`, `AiUploadCoordinator.enqueue`
- [x] 3.2 Implement success cleanup per section 9 and queue updates. → `AiUploadCoordinator` 成功删 `tasks/<uuid>/`、更新 `pending.json`、按 9.3 尝试删日期目录
- [x] 3.3 Hook AI inference “needs report” callback to enqueue tasks (lens vs metal). → `AiUploadFailureSampleHook`（需在具备失败帧文件路径处调用）

## 4. Documentation

- [x] 4.1 After implementation, cross-link `upload.md` to merged OpenSpec capability `ai-report-device-pipeline`. → 文首链接 + `openspec/specs/ai-report-device-pipeline/spec.md`
