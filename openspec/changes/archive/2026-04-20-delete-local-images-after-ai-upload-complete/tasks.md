## 1. Metadata and enqueue

- [x] 1.1 在 `AiUploadMetadata` 增加可选字段 `source_image_absolute_path`（ Gson 兼容：缺省为 null/省略）。
- [x] 1.2 在 `AiUploadCoordinator.enqueue` 复制成功后：若 `imageSource` 绝对路径经白名单校验通过，则写入 `metadata.json`；否则不写该字段（保持与今日行为一致）。

## 2. 安全删除与上传收尾

- [x] 2.1 实现 `tryDeleteSourceIfEligible(Context, String absolutePath)`：canonical 前缀校验、`isFile`、与任务副本路径不等价判断。
- [x] 2.2 在 `uploadOneTask` 成功路径（HTTP 成功、队列移除、`deleteRecursive(taskDir)` 之后）调用 2.1；删除失败只打日志，不影响返回值。

## 3. 文档与测试

- [x] 3.1 更新 `upload.md` 第 6/9 节（或新增小节）说明 `source_image_absolute_path` 与删除策略、白名单边界。
- [x] 3.2 增加单元测试：白名单内路径应删、白名单外不删、与 `image.jpg` 同路径不删、canonical 等价路径判断。
