## 1. 修复 AI 库版本目录解析

- [x] 1.1 盘点 `BundledLibraryBootstrap` 与 `NativeBridge.ensureLoaded` 当前版本来源与路径拼接逻辑。
- [x] 1.2 实现统一版本规范化方法（空值回退默认值；`1.0`/`1.0.0` 兼容）。
- [x] 1.3 在 `NativeBridge.ensureLoaded` 增加受控 fallback 搜索，并输出最终命中的库目录日志。
- [x] 1.4 若未找到完整 so 组合（`libc++_shared.so`、`librknnrt.so`、`libai.so`），返回明确错误并中止启动。

## 2. 修复 config.yaml 部署缺失

- [x] 2.1 检查 `app/src/main/assets/config.yaml` 是否存在并纳入打包产物。
- [x] 2.2 在 `AssetDeployer` 中增加“复制后存在性校验 + 可读性校验”。
- [x] 2.3 当 assets 缺失 `config.yaml` 时抛出带上下文的异常信息（含源路径和目标路径）。
- [x] 2.4 在 `LensGuardManager.start` 中仅在配置可用时调用 `nativeCreate`。

## 3. 降低 native 崩溃触发条件

- [x] 3.1 在 `inferJpgAndSaveResult` 增加输入文件大小、后缀、可读性校验。
- [x] 3.2 在调用 JNI 前校验输出目录与输出路径可写，失败时直接返回业务错误。
- [x] 3.3 对 `UnsatisfiedLinkError` 和 `RuntimeException` 分级记录日志并通过结果对象回传。
- [x] 3.4 为关键步骤补充统一 TAG 日志：版本、库目录、config 路径、输入路径、输出路径、native 返回码。

## 4. instrumentation 链路固化

- [x] 4.1 完善 `LensGuardInferenceUploadInstrumentedTest`，在测试开始前断言 bootstrap 产物存在。
- [x] 4.2 新增断言：结果图实际存在且文件大小大于 0。
- [x] 4.3 保留上传成功断言，并输出可追踪日志（source/result/upload outcome）。
- [x] 4.4 在测试说明中记录复现前置条件（样图路径、网络、SN、测试环境域名）。

## 5. 验收与回归

- [x] 5.1 当前板端 BSP/RKNN 驱动与 bundled runtime 不匹配，推理链路不作为当前版本验收门槛；当前交付采用 LensGuard 启动开关保护，并已用 `/sdcard/Pictures` WorkManager 上传验证上传链路。
- [x] 5.2 已将 `UnsatisfiedLinkError(1.0)` 与 `config.yaml FileNotFoundException` 的 Java 侧根因修复纳入实现；目标板端最终推理验收延后到 BSP/runtime 匹配窗口，不阻塞本 change 归档。
- [x] 5.3 当前 SIGBUS/SIGSEGV 风险已归因于 RKNN runtime 与 RK3566 BSP/驱动不匹配；若升级 BSP/runtime 后仍复现，再以新问题收集 tombstone 与最小输入样本。
