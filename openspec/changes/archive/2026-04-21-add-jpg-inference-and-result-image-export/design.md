## Context

当前引擎接入路径是实时视频流：`EasyPlayerClient` 回调 I420 `ByteBuffer`，`LensGuardManager.onI420Frame()` 拷贝成 `byte[]` 后调用 `NativeBridge.nativePushFrame()`。该链路适合持续推理，但不适合“给定一张 JPG 样图快速验证”的测试场景。

另一方面，检测结果仅上抛业务事件，不产出图片文件。测试上传/下载链路时，缺少稳定的结果文件作为输入输出样本，导致测试脚本和人工复核都不方便。

## Goals / Non-Goals

**Goals:**
- 新增单图推理入口：可直接传入 JPG 绝对路径触发 `libai.so` 推理。
- 新增结果图落盘能力：推理后自动生成图片文件并返回输出路径。
- 与现有回调机制兼容：继续保留 `onCheckResult`，并补充结果图路径给上层。
- 保持实时流推理链路不回归。

**Non-Goals:**
- 不重构现有实时推帧架构。
- 不新增复杂 UI 展示页面；仅补齐测试和数据链路所需能力。
- 不在本变更中定义云端上传协议，仅提供本地可用的结果文件。

## Decisions

### D1: JNI 采用新增方法，不复用 `nativePushFrame`

**Decision:**
- 在 `NativeBridge` 新增专用 JNI 方法，例如：
  - `nativeInferImage(long handle, String imagePath)`：按图片路径执行一次推理；
  - `nativeInferImageAndSave(long handle, String imagePath, String outputPath)`：推理并保存结果图（推荐）。

**Rationale:**
- `nativePushFrame` 的输入语义是 I420 内存帧，不应混用文件路径，避免接口语义混乱。
- 独立 JNI 方法便于 native 层后续扩展（旋转校正、阈值、可视化参数等）。

### D2: Java 层由 `LensGuardManager` 统一编排“单图推理 + 结果落盘”

**Decision:**
- 在 `LensGuardManager` 新增公开方法，例如：
  - `inferJpg(String imagePath)`（仅推理）；
  - `inferJpgAndSaveResult(String imagePath)`（自动生成输出路径并保存结果图）。
- 方法内统一进行：引擎运行态检查、输入路径校验、输出目录创建、JNI 调用、结果事件派发。

**Rationale:**
- `LensGuardManager` 已承载引擎生命周期与业务回调，继续作为单一入口可以减少上层耦合。

### D3: 结果图统一落盘目录与命名策略

**Decision:**
- 默认输出目录：`/sdcard/lws/result/`（若目录不存在自动创建）。
- 文件命名：`<sourceName>_result_<yyyyMMdd_HHmmss>.jpg`。
- 输出路径写入日志与事件，供上传模块直接消费。

**Rationale:**
- 统一目录便于测试脚本扫描与批量上传。
- 时间戳命名避免覆盖，便于追溯。

### D4: 结果事件增加文件路径字段（新增事件优先）

**Decision:**
- 保留 `LensCheckResultEvent(level, status, message)` 不破坏现有订阅逻辑。
- 新增 `LensCheckResultImageEvent`（或同等命名）承载：
  - `level`, `status`, `message`
  - `sourceImagePath`
  - `resultImagePath`
  - `success`, `errorMessage`

**Rationale:**
- 兼容旧逻辑，避免一次性修改所有订阅方。
- 新事件专注测试闭环，便于逐步接入上传下载流程。

## API Sketch

- `NativeBridge`（新增）
  - `public static native int nativeInferImageAndSave(long handle, String imagePath, String outputPath);`
    - 返回 `0` 表示成功，非 `0` 表示失败码（由 native 定义）。
- `LensGuardManager`（新增）
  - `public InferenceImageResult inferJpgAndSaveResult(String imagePath);`
  - `private String buildResultOutputPath(String imagePath);`

> `InferenceImageResult` 可为内部静态类或独立 data class，包含 `success/code/message/resultImagePath`。

## Flow

1. 业务层传入 `/sdcard/lws/picture/xxx.jpg`。
2. `LensGuardManager` 校验：
   - 引擎 `handle != 0`
   - 输入文件存在且可读
3. 构建输出路径并创建父目录。
4. 调用 `NativeBridge.nativeInferImageAndSave(handle, imagePath, outputPath)`。
5. 根据返回码：
   - 成功：发布结果图片事件 + 返回结果对象；
   - 失败：发布失败事件 + 返回错误对象。
6. 上传模块消费 `resultImagePath` 执行上传；下载模块可回拉核验。

## Risks / Trade-offs

- **Native 能力依赖**：若 `libai.so` 尚未实现新 JNI，Java 侧只能先完成接口与降级逻辑。
- **存储权限差异**：不同 Android 版本对 `/sdcard` 写入限制不同，需要结合现有项目权限策略验证。
- **结果图生成耗时**：单图推理+绘制可能比纯回调更慢，应避免在主线程调用。
- **文件体积增长**：批量测试会累积结果图，需要后续补充清理策略（非本次必做）。

## Validation Plan

- 使用本地样图调用 `inferJpgAndSaveResult`，验证返回成功且结果图文件存在。
- 校验事件中 `resultImagePath` 与实际落盘路径一致。
- 将结果图接入当前上传/下载测试链路，验证可上传、可下载、可打开。
- 回归实时流场景，确认 `nativePushFrame` 路径行为不变。
