## Context

`AiUploadCoordinator.enqueue` 将 `imageSource` 复制到 `files/ai_upload/.../image.jpg` 后排队；`AiUploadDrainWorker` 在 Worker 成功返回后删除 `tasks/<uuid>/`。原始 `imageSource` 常位于 App 私有或 `Android/data/<pkg>/` 下的结果目录，与任务副本并存，需在上传成功后回收。

## Goals / Non-Goals

**Goals:**

- Worker 已成功接受 `ai-report` 且任务目录已按现有逻辑删除后，在满足 **路径白名单** 时删除 **原始** 图片文件，减少磁盘占用。
- 持久化删除所需信息，使 **WorkManager 跨进程重试** 后仍能执行删除（不依赖调用方内存中的 `File` 引用）。
- 删除失败 **不得** 导致队列死循环：记录日志，视为非致命（任务已从队列移除）。

**Non-Goals:**

- 不删除任意 `/sdcard/Pictures`、公共相册等 **非 App 沙盒** 路径（除非未来单独增加显式用户授权与产品开关）。
- 不改变 Worker 协议、R2 路径、multipart 字段。
- 不改动「失败任务保留在队列 / `Result.retry()`」的总体策略（除非删除失败被误判为上传失败——本设计避免）。

## Decisions

1. **在 `metadata.json` 增加可选字段** `source_image_absolute_path`（字符串，规范化后的绝对路径）。  
   - **Rationale**：drain 在后台线程运行，仅靠入队时内存对象无法跨重启；JSON 与现有 `AiUploadMetadata` 一致，易序列化。  
   - **Alternative**：独立 `source.json` sidecar — 增加文件数，否决。

2. **删除条件（全部满足才删）**  
   - 字段非空且指向 **常规文件**（`isFile()`）。  
   - 规范化路径以 **`context.getFilesDir()`、`getCacheDir()`、`getNoBackupFilesDir()`、`getExternalFilesDir(null)`** 等返回的绝对路径为前缀（取 canonical path 或 `startsWith` 在规范化后比较），覆盖 `files/`、`cache/`、`Android/data/<pkg>/files` 等 App 可控区域。  
   - **不得** 与任务内 `image.jpg` 为同一路径（避免在复制为硬链接或同路径的极端实现下双删逻辑混乱）。  
   - **Rationale**：满足「本地已完成上传后删图」且避免误删用户内容。  
   - **Alternative**：`enqueue` 增加 `boolean deleteSourceAfterSuccess` — 调用方易忘设；路径白名单更保守，可与之组合；首版以白名单 + 持久化路径为主。

3. **执行时机**  
   - 在 **`postAiReport` 成功**、**已从 `pending.json` 移除 taskId**、**已 `deleteRecursive(taskDir)`** 之后调用 `tryDeleteSourceIfEligible(Context, path)`。  
   - **Rationale**：先保证云端成功再删原图；任务目录先删避免与副本路径混淆。

4. **删除失败**  
   - 打 `Log.w`，**不** 将任务重新加回队列，**不** 返回 `false` 触发额外 WM retry（避免把「删源失败」当成「上传失败」）。

## Risks / Trade-offs

- **[Risk] 白名单过宽** → 误删 App 内其他业务仍需要的文件 → 仅删「入队时记录的单一源路径」、且前缀严格限定为应用私有/外部 files 根。  
- **[Risk] 路径规范化差异**（符号链接、`/data/user/0` vs `/data/data`）→ 使用 `File.getCanonicalFile()` 再比较前缀。  
- **[Risk] 旧任务无新字段** → 不删源图，行为与今日一致 → 可接受。

## Migration Plan

- 新字段可选：旧 `metadata.json` 无字段 → 跳过源删除。  
- 无需服务端迁移。

## Open Questions

- 是否需要在 `enqueue` 增加显式 `deleteSource` 开关以便 **非沙盒但业务约定** 的路径（默认 **否**，留给后续变更）。
