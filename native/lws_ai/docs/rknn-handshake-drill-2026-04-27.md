# RKNN 联调演练记录（2026-04-27）

## 演练目标

- 验证新旧模型命名兼容构建是否可稳定通过；
- 验证 RKNN 初始化阶段日志与 I/O 路径切换能力已具备；
- 形成可复用的 App 回传模板与结论输出方式。

## 演练输入

- 新命名模型：`assets/models/cls.rknn`、`assets/models/det.rknn`
- legacy 命名模型：`v8_cls_i8.rknn`、`v8_lens_det_i8.rknn`（由脚本临时生成）
- 构建脚本：`check_model_name_compat.ps1`

## 演练步骤

1. 以新命名模型执行 Android `ai` 目标构建；
2. 自动切换为 legacy 命名场景再次构建；
3. 构建结束后恢复新命名文件；
4. 记录阶段日志与构建结果。

## 演练结果

- 新命名构建：通过
- legacy 命名构建：通过
- 最终恢复：通过（`cls.rknn`、`det.rknn` 已恢复）
- 结论：模型命名兼容链路可用于联调阶段快速切换，不影响主构建。

## 输出工件

- 兼容性检查脚本：`check_model_name_compat.ps1`
- 回传模板：`docs/rknn-app-feedback-template.md`

## 下一步

- App 按模板回传一轮真实设备日志与 tombstone；
- YOLO 侧根据“最后成功阶段标签 + ret code”判定是否继续走 `IO_MEM` 或切换到 `LEGACY_IO`。
