## Why

当前镜片检测 JNI 入口仅支持 `nativePushFrame(handle, data, width, height)`，输入必须是 I420 帧，无法直接给 `/sdcard/lws/picture/*.jpg` 这样的图片路径做一次性推理。这导致测试流程必须先走视频解码管道，无法快速验证单张样图。

同时，检测结果目前只通过 `onCheckResult(level, status, message)` 回调上抛到 EventBus，用于日志和业务事件，不会自动输出“结果图文件”。这使测试上传/下载链路时缺少可落盘、可回传、可复核的产物。

为降低联调成本，需要补齐“图片路径直推理 + 结果图落盘”两项能力，支持测试人员用本地 JPG 快速触发推理，并将结果图保存到指定目录用于上传和下载回归。

## What Changes

- 在 `NativeBridge` 新增“按 JPG 路径执行推理”的 JNI 能力（新增 native 方法，不替代现有 I420 推帧能力）。
- 在 `LensGuardManager` 新增面向测试的入口：传入图片路径触发一次推理，返回结构化结果并保持现有回调兼容。
- 新增“结果图保存”能力：将推理输出（原图+标注/状态信息）写入本地文件（建议默认目录 `/sdcard/lws/result/`）。
- 新增结果文件事件或回调字段（例如输出路径、文件名、时间戳），便于业务层上传并在下载后核对。
- 保持现有实时流推理链路不受影响（`nativePushFrame` 与 `onI420Frame` 继续可用）。

## Capabilities

### New Capabilities
- `jpg-path-inference`: 允许直接传入 JPG 文件路径调用 `libai.so` 推理，绕过实时解码管道。
- `inference-result-image-export`: 将推理结果保存为图片文件并返回文件路径，支持上传下载测试闭环。
- `result-file-metadata-event`: 向上层暴露结果文件元信息（路径、状态、时间）用于日志与业务编排。

### Modified Capabilities
- `native-bridge-jni`: 从仅 I420 推帧扩展为“实时推帧 + 单图路径推理”双入口。
- `detection-callback-handler`: 在现有状态/告警/检测结果事件基础上，补充结果文件落盘信息。

## Impact

- **代码改动**：
  - `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java`：新增 JNI 方法声明与注释。
  - `app/src/main/java/com/lasercyber/lws/ai/LensGuardManager.java`：新增图片路径推理与结果图保存编排方法。
  - `app/src/main/java/com/lasercyber/lws/ui/bean/event/`：新增或扩展事件对象以携带结果图路径。
  - （如需要）新增 `ResultImageSaver` 或同类工具类统一管理文件名与目录策略。
- **Native 对齐**：
  - 需要 YOLO `libai.so` 提供对应 JNI 实现（按路径推理、输出可保存结果图或返回可视化数据）。
- **权限与存储**：
  - 涉及 `/sdcard/lws/...` 路径时需确认 Android 存储权限/分区存储兼容策略。
- **测试收益**：
  - 可直接用固定样图验证推理正确性，且产出可上传下载的结果图，显著降低联调复杂度。
