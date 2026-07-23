## Context

现有实现将上传任务副本写入 `files/ai_upload/.../tasks/<uuid>/image.jpg`，上传成功后删除任务目录；此前新增能力仅允许删除 App 私有/外部 files 根下的原始图，不覆盖 `/sdcard/Pictures`。而当前真实操作中，图片来源常是 `/sdcard/Pictures`，用户希望上传完成后自动回收该目录中的已完成图片。

## Goals / Non-Goals

**Goals:**

- 在 `ai-report` 上传成功后，支持删除 `/sdcard/Pictures` 下已上传的原图。
- 仍保留安全边界：仅删除“本任务元数据记录的源文件”且通过路径校验，避免扩大误删面。
- 删除失败不影响上传成功判定，不触发无意义队列重试。

**Non-Goals:**

- 不删除 `Pictures` 以外的任意共享存储目录。
- 不新增服务端字段或改变 Worker API。
- 不修改队列模型（pending/retry 语义保持不变）。

## Decisions

1. 扩展删除白名单：在既有 App-owned 根目录外，额外允许 canonical path 命中 `/sdcard/Pictures`（等价 `/storage/emulated/0/Pictures`）的文件。
   - 备选：全放开共享存储删除，风险过高，拒绝。

2. 入队时继续持久化 `source_image_absolute_path`，并新增来源类别判定（如 `source_location=shared_pictures` 可选）用于日志可观测性；删除动作仍以 canonical path 校验为准。
   - 备选：仅靠运行时路径前缀判断，不落库来源标记。可行，但可观测性差。

3. 删除时机保持在成功上传后：队列移除 + task 目录删除之后调用 `tryDeleteSourceIfEligible`，与现有清理顺序一致。

4. 对共享目录删除失败采用“记录并跳过”：`Log.w`，不将任务回滚到 pending。

## Risks / Trade-offs

- [Risk] 误删用户相册文件 → Mitigation: 只允许 `/sdcard/Pictures` 精确前缀且必须是 metadata 绑定的单文件路径。
- [Risk] 厂商 ROM 路径别名差异（`/sdcard` vs `/storage/emulated/0`）→ Mitigation: canonical 规范化后统一比较。
- [Risk] 删除权限差异（Scoped Storage/权限收紧）→ Mitigation: 删除失败只告警，不影响上传完成；必要时由产品侧增加显式开关。

## Migration Plan

- 与现有 metadata 向后兼容：旧任务没有源路径字段则不尝试删除共享目录。
- 无需服务端迁移。

## Open Questions

- 是否需要增加运行时开关（例如仅在特定渠道/机型启用共享目录删除）以便灰度。
