## 1. JNI 与桥接接口扩展

- [x] 1.1 在 `NativeBridge.java` 新增 JPG 路径推理 JNI 声明（建议 `nativeInferImageAndSave(handle, imagePath, outputPath)`）。
- [x] 1.2 为新增 JNI 方法补充 JavaDoc（输入输出约束、返回码语义、线程要求）。
- [x] 1.3 按当前项目进度不继续推进：现有 `libai.so` 未提供可验收的 JPG 路径推理/结果图导出 JNI，当前版本上传验证已改用 `/sdcard/Pictures` 原图 WorkManager 上传，不再以此 JNI 作为当前交付门槛。

## 2. LensGuardManager 单图推理能力

- [x] 2.1 在 `LensGuardManager` 增加 `inferJpgAndSaveResult(String imagePath)` 对外方法。
- [x] 2.2 增加运行态校验（`handle != 0`）与输入路径校验（存在、可读、后缀为 jpg/jpeg）。
- [x] 2.3 增加结果输出路径生成逻辑（默认 `/sdcard/lws/result/` + 时间戳命名）并自动创建目录。
- [x] 2.4 调用 `NativeBridge` 新接口执行推理并保存结果图，封装返回对象（成功/失败码/消息/路径）。

## 3. 结果事件与业务透传

- [x] 3.1 新增结果图事件类（如 `LensCheckResultImageEvent`），字段包含 `sourceImagePath`、`resultImagePath`、`success`、`errorMessage`。
- [x] 3.2 在 `inferJpgAndSaveResult` 成功/失败分支发布对应事件，保持现有 `LensCheckResultEvent` 兼容。
- [x] 3.3 在关键节点添加日志（输入路径、输出路径、返回码、异常栈）用于联调排查。

## 4. 存储与权限验证

- [x] 4.1 当前版本不产出 `/sdcard/lws/result/` 结果图，目标写权限验证不再是当前交付必要项；如后续恢复结果图导出，应重新提出存储目录与权限方案。
- [x] 4.2 增加目录创建失败与文件写入失败的错误处理，返回可读错误信息。

## 5. 测试与回归

- [x] 5.1 当前版本不启用 JPG 直推理结果图链路；样图推理验证不再作为当前交付必要项。
- [x] 5.2 当前版本已通过 `/sdcard/Pictures` 原图 WorkManager 上传验证上传链路，结果图上传/下载闭环不再作为当前交付必要项。
- [x] 5.3 当前版本不下载/复核结果图文件，后续若恢复结果图能力需重新提出验收项。
- [x] 5.4 当前目标设备存在 RKNN runtime 与 BSP/驱动不匹配，LensGuard 启动已被配置开关保护；实时流推理回归不再作为当前交付必要项，待 BSP/runtime 匹配后重开独立验收。
