## 1. 元数据与路径分类

- [x] 1.1 在 `AiUploadMetadata`（或等价结构）补充共享目录来源标记（可选）并保持向后兼容。
- [x] 1.2 `enqueue` 阶段将 `/sdcard/Pictures` 来源图片的 canonical 绝对路径写入 metadata，供 WorkManager 成功后清理。

## 2. 删除策略扩展

- [x] 2.1 扩展 `AiUploadSourceDelete` 白名单：支持 `/sdcard/Pictures`（含 canonical 等价路径）。
- [x] 2.2 在成功上传路径保持“先删 task 副本，再删 source 原图”；source 删除失败只日志，不回滚任务状态。

## 3. 文档与验证

- [x] 3.1 更新 `upload.md`：明确 `/sdcard/Pictures` 上传完成后的删除规则与边界（仅 Pictures，不含 Download 等）。
- [x] 3.2 增加/更新单测：Pictures 删除成功、非 Pictures 共享路径不删、路径别名 canonical 匹配。
