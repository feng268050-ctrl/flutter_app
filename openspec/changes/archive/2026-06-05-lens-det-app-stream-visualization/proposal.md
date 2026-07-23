## Why

OpenCV **lens_det**（`nativeOpencvStainDetectFrom*`）已在 `libai.so` 与 `NativeBridge` 中可用，但 App 未实现抽帧传帧、JSON 解析与可视化。产品需要在 **实时**（PR1 / AI Vision 直播）与 **离线**（单图 / 工艺视频）场景下对照现有 **RKNN** 路径使用 lens_det：native 负责检测并返回 JSON，App 只负责采样、解析与 overlay 展示。

## What Changes

- 新增 **lens_det App 推理层**：对照 `AiManager.inferFromI420` / `inferFromJpg`（RKNN 一次性）与 PR1 抽帧限频（RKNN 流式 push），在相同帧源上调用 `nativeOpencvStainDetectFromI420` / `FromJpg`。
- 新增 **JSON 解析**：解析 JNI summary JSON（`ok`/`code`/`files`）并读取 `target.json`（`name`,`x`,`y`），映射为 App 侧 `LensDetDetectResult`（供 UI / overlay 使用）。
- 新增 **实时路径**：Quick/Engineer 激光 ON 时 PR1 I420 经采样 gate 触发 lens_det；AI Vision 直播 TextureView 经 500ms gate 触发 lens_det（与 RKNN live 并行或可选模式，见 design）。
- 新增 **离线路径**：单图 JPG 与工艺视频帧（`ProcessVideoAiSession` 500ms 网格）调用 `nativeOpencvStainDetectFromJpg` / `FromI420`。
- 新增 **可视化**：将 `LensDetDetectResult` 转为 overlay 几何（目标点 / 可选小框）并在 AI Vision 直播、工艺视频 Detect 与可选 SSE/HTTP 路径展示；**不**在 App 端重算 OpenCV 算法。
- **Native（可选增强）**：若 v1 仅 summary + 文件路径，App 读 `target.json`；后续可将 `x`/`y` 内联进 summary JSON 以减少 IO（非阻塞 v1）。

## Capabilities

### New Capabilities

- `lens-det-app-inference`: App 抽帧/传帧、调用 lens_det JNI、解析 JSON、实时与离线调度（对照 RKNN infer 模式）。
- `lens-det-visualization`: 将 lens_det 检测结果映射为 overlay / compositor 输入并在 AI Vision 相关 UI 展示。

### Modified Capabilities

- `ai-frame-sampling-inference`: 增加 lens_det 复用现有采样 interval 的 gate 实例与 busy-drop 语义说明。
- `ai-vision-live-inference-overlay`: 增加 lens_det 结果 hold-forward 与 compositor 展示要求（与 RKNN unified result 并行或模式切换）。

## Impact

- **Java**: 新 `LensDetDetectJson` / `LensDetDetectResult` / `LensDetDetectResultMapper`；`LensDetDetectCoordinator` 或 `AiManager` 扩展；`ProductionInferenceStreamClient` / `AiVisionFragment` / `ProcessVideoAiSession` 集成点。
- **Native**: v1 无强制 API 变更；可选 summary JSON 内联 target 坐标。
- **配置**: 复用 `config.yaml` → `lens_det:`（经 RKNN engine handle 读取）。
- **部署**: `make sync`（Java + assets）；见 `docs/OPENCV_DETECT_APP_INTEGRATION.md`。
- **文档**: `native/lensinspector/docs/LENS_DET_NATIVE_API.md` App 集成状态更新。
