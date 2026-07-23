## Why

AI 库横跨 Native `libai.so`、Java `com.lasercyber.lws.ai`、UI 集成与 `ai-library` 模型资产四层，经审查存在扁平大包、双架构残留、UI↔AI 循环依赖等结构问题，以及帧路径多次 `clone()`、每模块独立 JNI 回调、标量 RKNN 预处理等性能热点。直播检测已迁移至 C++ `StreamDetectPipeline`，现在是收敛结构、消除热点、建立可度量基线的合适时机。

## What Changes

- **Phase 0 — 基线**：落地 `ai-library/README.md`；`LENS_INFER_TIMING=1` 采集 stain / stream detect 各阶段耗时与 `libai.so` 体积基线
- **Phase 1 — 低风险清理**：删除或 `@Deprecated` 无调用方的 Legacy Java 推帧 API；`roi_config_common` 静态库消除重复编译；`main.cpp` → `central_scheduler.cpp`；CMake 显式源文件列表替代 GLOB
- **Phase 2 — 性能 P0**：双槽环形帧缓冲消除 BGR 三重拷贝；Stream detect 合并单条 JNI JSON 回调；RKNN 预处理改 `blobFromImage` + output buffer 复用
- **Phase 3 — 结构重组**：Java `ai/` 按域划分子包（bridge / engine / stream / stain / zeropoint / sampling / model）；结果 DTO 去除 `DetectionOverlayView` 依赖；`ZeroPointManualAutoCoordinator` 拆分；Native 巨型文件拆分；`ENABLE_EDGEDRAWING` 可选编译开关
- **Phase 4 — 离线路径（按需）**：`ProcessVideoAiSession` ByteBuffer pool；Native I420 直通离线 infer；Stain worker 线程池 + 优雅 shutdown
- **非目标**：不重写 RKNN 算法；不恢复 `RKNN_STAIN_INFER_ACTIVE` Java 推帧路径；首期不拆分多个 `.so`

## Capabilities

### New Capabilities

- `ai-java-package-structure`: Java `com.lasercyber.lws.ai` 按域划分子包，单文件行数上限，Legacy API 清理，AI 核心与 UI View 解耦
- `ai-native-build-structure`: Native 源文件重命名与拆分、CMake 显式列表、`roi_config_common`、可选模块编译开关（`ENABLE_EDGEDRAWING` / `ENABLE_RKNN_STAIN`）
- `ai-frame-ring-buffer`: `CentralScheduler` 双槽环形缓冲 + swap，将 stain 路径 BGR 拷贝从 3 次降至 ≤1 次
- `stream-detect-combined-callback`: 每采样帧合并各模块结果为单条 JNI JSON 事件，`StreamDetectResultBus` 内部分发
- `ai-rknn-preprocess-optimization`: RKNN BGR→NCHW 改 `blobFromImage`、output buffer 复用、`det_raw_concat` buffer 复用
- `ai-library-local-assets`: `ai-library/README.md` 说明本地必需文件、缓存目录与 `make ai` 命令

### Modified Capabilities

- `stream-detect-result-bus`: 新增 `onCombinedFrame` 解析合并 JSON（`modules` 键按模块分发），per-module 回调标记废弃后移除
- `native-stream-detect-pipeline`: 帧环形缓冲集成、合并事件发布、Stain worker 生命周期（join 替代 detach）
- `offline-inference-nv12`: session 级 ByteBuffer pool 复用；可选 Native I420 直通离线 infer 路径

## Impact

- **Native / libai.so**: `central_scheduler.cpp`、`FrameRingBuffer`、`stream_detect_event.cpp` 合并回调、`rknn_runner.cpp` / `stain_preprocess.cpp` 优化、CMake 结构改造；`libai.so` 目标体积 −10~15%（`ENABLE_EDGEDRAWING=OFF`）
- **Java**: `com.lasercyber.lws.ai` 子包迁移（分批 PR）；`StreamDetectResultBus`、`NativeStreamDetectCoordinator` 适配合并回调；结果 DTO 改用 `NormalizedBox`；`ZeroPointManualAutoCoordinator` 拆分
- **UI**: `DetectionOverlayView` 映射层迁至 `ui/common/ai/overlay/`；`LensDetConsecutiveOkFilter` 改接受 `sampleIndexMs` 参数
- **构建与资产**: `native/lensinspector/CMakeLists.txt`、`scripts/make/build-ai.sh`；新增 `ai-library/README.md`（目录内容仍 gitignore）
- **验证**: `LENS_INFER_TIMING` 对比、`verify_libai_jni.sh`、直播 AI Vision + 焊接 stain/零点仪器测试、离线 process-video bbox IoU ≥0.95
