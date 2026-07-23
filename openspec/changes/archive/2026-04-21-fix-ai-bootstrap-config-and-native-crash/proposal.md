## Why

本轮实测“推理 -> 结果图 -> 云端上传”链路未跑通，已定位 3 个关键问题：

1. **AI 动态库版本目录不一致**：JNI 在 `.../ai-library/1.0/...` 查找，但实际解压目录是 `1.0.0`，首次触发 `UnsatisfiedLinkError`（找不到 `libc++_shared.so`）。
2. **推理配置文件缺失**：`AssetDeployer` 报 `FileNotFoundException: config.yaml`，说明运行时必需配置未落到预期位置。
3. **原生层崩溃**：在前两项异常后出现 `Fatal signal 11 (SIGSEGV)`，导致结果图未产出，上传自然失败。

这些问题使新加的 `LensGuardInferenceUploadInstrumentedTest` 无法稳定通过，当前功能不满足“可复现、可回归、可联调”的上线标准。

## What Changes

- 修复 AI 库加载路径与版本解析逻辑，确保 `NativeBridge.ensureLoaded` 与 `BundledLibraryBootstrap` 使用同一版本来源和目录约定。
- 修复 `config.yaml` 部署流程，明确配置来源与落地路径，避免运行时缺失。
- 在引擎启动与单图推理入口补充保护逻辑，降低 native 输入不完整时直接崩溃的风险。
- 增强日志与错误回传，确保能区分“库缺失 / 配置缺失 / native 调用失败”。
- 将 `LensGuardInferenceUploadInstrumentedTest` 作为主验收链路，验证推理结果图可生成并上传成功。

## Capabilities

### New Capabilities
- `ai-bootstrap-diagnostics`: AI 启动前置自检（库目录、关键 so、config.yaml）并输出明确诊断日志。
- `inference-upload-e2e-test-gate`: 通过 instrumentation 用例验证“推理+上传”主链路可用。

### Modified Capabilities
- `native-library-loader`: 版本目录解析与库加载路径统一。
- `config-asset-deploy`: 配置文件部署从“可能缺失”改为“可校验可恢复”。
- `jpg-path-inference`: 单图推理入口增加前置校验与失败降级。

## Impact

- **主要改动文件（预期）**：
  - `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java`
  - `app/src/main/java/com/lasercyber/lws/ai/AssetDeployer.java`
  - `app/src/main/java/com/lasercyber/lws/ui/common/upgrade/BundledLibraryBootstrap.java`
  - `app/src/main/java/com/lasercyber/lws/ai/LensGuardManager.java`
  - `app/src/androidTest/java/com/lasercyber/lws/ui/ai/LensGuardInferenceUploadInstrumentedTest.java`
- **风险与收益**：
  - 启动阶段会增加少量自检开销，但换来明显更高的稳定性和可诊断性。
  - native 崩溃问题可能仍需 C++ 侧配合，但 Java 侧将先行收紧输入边界并减少触发条件。
