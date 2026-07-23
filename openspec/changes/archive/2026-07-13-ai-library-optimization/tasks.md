## 1. Phase 0 — 基线与文档

- [x] 1.1 创建 `ai-library/README.md`（必需文件、缓存目录、`make ai` 命令）
- [x] 1.2 `LENS_INFER_TIMING=1 make ai` 采集 stain / stream detect 各阶段耗时基线（logcat）
- [x] 1.3 记录当前 `libai.so` 体积与 APK AI 相关增量基线

## 2. Phase 1 — Native 低风险清理

- [x] 2.1 新增 `roi_config_common` 静态库，从 `zero_point_core` / `edgedrawing_core` 移除重复 `roi_config.cpp`
- [x] 2.2 `main.cpp` 重命名为 `central_scheduler.cpp` + `central_scheduler.h`，更新 CMake
- [x] 2.3 CMake 显式 `AI_JNI_SOURCES` 列表替代 `file(GLOB src/*.cpp)`
- [x] 2.4 运行 `make ai` + `verify_libai_jni.sh` 验证 Phase 1 Native 变更

## 3. Phase 1 — Java Legacy 清理

- [x] 3.1 删除或 `@Deprecated` `AiManager.onBitmapFrame`、`tryAcceptOpencv*`、`tryAcceptRknn*`（确认无调用方）
- [x] 3.2 删除无调用方的 `Nv12FrameUtil.copyToDirectBuffer` / `i420DirectToNv12Direct`（若适用）
- [x] 3.3 文档标注 `RKNN_STAIN_INFER_ACTIVE` 为保留开关，非当前 live 路径
- [x] 3.4 全量编译 + 现有 unit test 通过

## 4. Phase 2 — 帧环形缓冲（P0）

- [x] 4.1 实现 `FrameRingBuffer`（双槽 + swap + `cv::Mat` 引用计数）
- [x] 4.2 集成至 `CentralScheduler`：`pushFrame` / `waitFrame` / `worker_stain` 去除多余 `clone()`
- [x] 4.3 添加 `LWS_FRAME_RING_BUFFER` CMake 选项（默认 ON）与 clone 回退路径
- [x] 4.4 `LENS_INFER_TIMING` 对比 `frame_copy_ms` 下降 ≥50%；直播 stain 功能回归

## 5. Phase 2 — Stream Detect 合并 JNI 回调（P0）

- [x] 5.1 `stream_detect_event.cpp`：每采样帧累积各模块结果，一次 `publishStreamDetectEvent`
- [x] 5.2 `StreamDetectNativeCallback` / `StreamDetectResultBus`：新增 `onCombinedFrame` 解析 `modules` 分发
- [x] 5.3 旧 per-module 回调标记 `@Deprecated`，Bus 适配层保持 Coordinator API 不变
- [x] 5.4 `StreamDetectResultBus` unit test + 真机 AI Vision / 焊接回归；logcat 确认每帧 1 次 JNI

## 6. Phase 2 — RKNN 预处理与输出优化（P0）

- [x] 6.1 `stain_preprocess` 改 `cv::dnn::blobFromImage`；CMake 保留标量回退选项
- [x] 6.2 离线对比脚本验证 blobFromImage vs 标量路径 FP 容差
- [x] 6.3 `rknn_runner` output buffer 复用（`output_buffers_`）
- [x] 6.4 `det_raw_concat` 使用 thread_local / 成员 buffer 复用
- [x] 6.5 `LENS_INFER_TIMING` 对比 `preprocess_ms` / `rknn_run_ms`；长时间稳定性测试

## 7. Phase 3 — Java 子包迁移（分批 PR）

- [x] 7.1 迁移 `bridge/` 子包（`NativeBridge`, `AiNativeRuntime`, `AiLibraryDirectory`, `AssetDeployer`）
- [x] 7.2 迁移 `stream/` 子包（`NativeStreamDetectCoordinator`, `StreamDetectResultBus`, 等）
- [x] 7.3 迁移 `stain/` 子包（Coordinators, ResultMappers, Filters）
- [x] 7.4 迁移 `zeropoint/` 子包（Coordinators, Sessions, JSON/ROI）
- [x] 7.5 迁移 `sampling/` 与 `engine/` 子包（`AiFrameSamplingGate`, `AiManager` 瘦身）
- [x] 7.6 迁移 `model/` 子包（纯数据 DTO，去除 `DetectionOverlayView` 依赖）

## 8. Phase 3 — UI 解耦与 Coordinator 拆分

- [x] 8.1 结果 DTO 改用 `NormalizedBox`；`DetectionOverlayView` 映射层迁至 `ui/common/ai/overlay/`
- [x] 8.2 `LensDetConsecutiveOkFilter` 改接受 `sampleIndexMs`，移除 `ProcessVideoAiTimeline` import
- [x] 8.3 拆分 `ZeroPointManualAutoCoordinator` → Workflow / LaserController / VideoAnalyzer
- [x] 8.4 Overlay 显示 + 手动零点自动校正全流程仪器测试

## 9. Phase 3 — Native 结构深化

- [x] 9.1 共享 JSON helper（`json_escape.h` 或扩展 `det_callback_json`），统一各 `*_json.cpp`
- [x] 9.2 拆分巨型源文件（`scan_v_channel_radial_adaptive`, `det_postprocess`, `fixed_roi_pipeline`）
- [x] 9.3 添加 `ENABLE_EDGEDRAWING` / `ENABLE_RKNN_STAIN` CMake 选项；对比两种构建 `libai.so` 体积
- [x] 9.4 `verify_libai_jni.sh` 按构建配置检查符号

## 10. Phase 4 — 离线路径与 Worker 生命周期（按需）

- [x] 10.1 `ProcessVideoAiSession` session 级 ByteBuffer pool 复用
- [ ] 10.2 （可选）Native `nativeOpencvStainDetectFromI420Direct` 离线直通
- [x] 10.3 `StainWorkerPool` 替代 detach；`CentralScheduler` 析构 `shutdown()` + join
- [ ] 10.4 离线 process-video bbox IoU ≥0.95 对比验证

## 11. 验收

- [x] 11.1 结构验收：`ai/` ≥5 子包、无单文件 >1500 行、无 `ui.*.view` import、CMake 无 GLOB、`roi_config` 只编译一次
- [x] 11.2 性能验收：`frame_copy_ms` 下降 ≥50%、每采样帧 JNI 1 次、直播 AI Vision + 焊接通过
- [x] 11.3 回填 `docs/AI_LIBRARY_OPTIMIZATION_DESIGN.md` §5 checklist 与 §3.2 性能数字
