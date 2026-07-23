## Context

AI 库由四层组成：Native `libai.so`（~15k 行 C++）、Java `com.lasercyber.lws.ai`（56 文件扁平大包）、UI 集成层、以及 gitignored 的 `ai-library/` 模型资产。直播推理已迁移至 C++ `StreamDetectPipeline` 直接消费 PR1 RTSP；Java 负责配置启停与 JSON 回调分发，`RKNN_STAIN_INFER_ACTIVE = false` 关闭 Java 推帧路径。

当前热点：帧路径三重 BGR `clone()`、每模块独立 JNI 回调、标量 RKNN 预处理、Java 扁平大包与 UI 循环依赖。详细审查见 [`docs/AI_LIBRARY_OPTIMIZATION_DESIGN.md`](../../../docs/AI_LIBRARY_OPTIMIZATION_DESIGN.md)。

## Goals / Non-Goals

**Goals:**

- Java `ai/` 按域划分子包，单文件 ≤500 行（桥接层 ≤800）；清除 Legacy 推帧 API；打断 AI 核心与 UI View 循环依赖
- Native 源文件按职责拆分；CMake 显式列表 + `roi_config_common`；`main.cpp` → `central_scheduler.cpp`
- P0 性能：帧环形缓冲（BGR 拷贝 ≤1 次）、合并 JNI 回调（每采样帧 1 次）、RKNN `blobFromImage` + buffer 复用
- 可选 `ENABLE_EDGEDRAWING` 编译开关；`ai-library/README.md` 落地
- 建立 `LENS_INFER_TIMING` 基线与验收指标

**Non-Goals:**

- 不重写 RKNN 模型或后处理算法逻辑
- 不恢复 `RKNN_STAIN_INFER_ACTIVE` Java 推帧路径
- 首期不拆分 `libai.so` 为多个 `.so`
- Phase 4 离线路径（ByteBuffer pool、I420 直通）按需实施，不阻塞 Phase 0–3

## Decisions

### D1: 分阶段落地，Phase 1 先于结构大迁移

**选择**：Phase 0（基线）→ Phase 1（低风险清理）→ Phase 2（P0 性能）→ Phase 3（结构重组）→ Phase 4（按需）。

**理由**：清理与性能优化风险可控、可度量；Java 子包迁移分批 PR 降低 import 遗漏风险。

**备选**：一次性大重构 — 拒绝，回归面过大。

### D2: 帧缓冲 — 双槽环形 + swap，非单缓冲共享

**选择**：`FrameRingBuffer` 双槽，`publish()` 写下一槽后 swap `write_idx_`；`consume()` 取最新 ready 槽，不深拷贝 `cv::Mat`（引用计数安全）。

**理由**：`pushFrame` 在解码线程、`worker_stain` 在独立线程；双槽保证生产者不覆盖消费者正在读的 Mat。Worker 需修改帧时内部 `clone()` 一次即可。

**回退**：CMake 选项 `LWS_FRAME_RING_BUFFER`（默认 ON），可恢复 `clone()` 路径。

### D3: Stream detect — 合并 JSON 单回调，Bus 内部分发

**选择**：Native 每采样帧累积各模块结果，帧结束时一次 `publishStreamDetectEvent`：

```json
{ "frame_pts_ms": 1500, "modules": { "lens_det": {...}, "zero_point": {...} } }
```

Java `StreamDetectResultBus` 解析 `modules` 后按 key 分发给已有 per-module listener；对外 Coordinator API 不变。

**理由**：减少每帧 N 次 `NewStringUTF` + `CallVoidMethod`；Bus 适配层隔离下游变更。

**回退**：保留旧 per-module 回调分支一个版本，标记 `@Deprecated` 后删除。

### D4: RKNN 预处理 — `cv::dnn::blobFromImage` 替代标量循环

**选择**：`stain_preprocess::BgrToNchwFloat` 改用 `cv::dnn::blobFromImage(roi, 1/255.0, Size(640,640), Scalar(), true, false, CV_32F)`；output 用成员 `output_buffers_` 复用。

**理由**：OpenCV 内部可用 SIMD/NEON；离线对比脚本验证 FP 容差。

**回退**：CMake 选项保留标量实现。

### D5: Java 子包 — 每 PR 迁一个子包，对外 API 兼容

**选择**：目标结构 `bridge/`、`engine/`、`stream/`、`stain/`、`zeropoint/`、`sampling/`、`model/`；`AiManager.getInstance()` 等对外入口保持，内部委托新类。

**理由**：IDE 批量重构 + 独立编译验证；避免单 PR 改动 56 文件。

### D6: UI 解耦 — 纯几何 DTO + 映射层

**选择**：`AiStainDetectResult` 等改用 `List<NormalizedBox>`（x,y,w,h 0..1）；`DetectionOverlayView` 映射迁至 `ui/common/ai/overlay/`；`LensDetConsecutiveOkFilter` 接受 `int sampleIndexMs`，不 import `ProcessVideoAiTimeline`。

### D7: CMake — 显式源列表 + `roi_config_common` 静态库

**选择**：
- `add_library(roi_config_common STATIC src/zero_point/roi_config.cpp)` 被 `zero_point_core` 与 `edgedrawing_core` 共享
- `set(AI_JNI_SOURCES ...)` 替代 `file(GLOB SOURCES src/*.cpp)`
- `option(ENABLE_EDGEDRAWING ...)` / `option(ENABLE_RKNN_STAIN ...)`

### D8: Stain worker — 有界线程池 + `shutdown()` join

**选择**：`StainWorkerPool` 替代 `std::thread(...).detach()`；`CentralScheduler` 析构时 `shutdown()` drain + join。

**理由**：消除 detach UAF 风险。归入 Phase 4（P1），不阻塞 P0。

## Risks / Trade-offs

| 风险 | 缓解 | 回退 |
|------|------|------|
| 帧缓冲 swap 竞态 | 双槽 + `cv::Mat` 引用计数；长时间直播仪器测试 | `LWS_FRAME_RING_BUFFER=OFF` |
| `blobFromImage` 数值偏差 | 离线对比脚本；容差阈值测试 | CMake 保留标量实现 |
| 合并 JNI 回调破坏下游 | Bus 适配层保持 per-module listener | 旧回调分支保留一版 |
| Java 子包 import 遗漏 | 分批 PR；CI 全编译 | Git revert 单批 |
| `ENABLE_EDGEDRAWING=OFF` 漏符号 | `verify_libai_jni.sh` 按构建配置检查 | 默认 ON |

## Migration Plan

1. **Phase 0**（0.5 周）：评审本文档；`ai-library/README.md`；采集 TIMING 基线与 `libai.so` 体积
2. **Phase 1**（1 周）：Legacy API 清理、`roi_config_common`、`central_scheduler` 重命名、CMake 显式列表
3. **Phase 2**（1–2 周）：帧环形缓冲、合并 JNI、RKNN 预处理优化
4. **Phase 3**（2–3 周）：Java 子包分批迁移、DTO 解耦、Native 巨型文件拆分、`ENABLE_EDGEDRAWING`
5. **Phase 4**（按需）：离线 ByteBuffer pool、I420 直通、Stain worker 池

每 Phase 完成后：`make ai` + `verify_libai_jni.sh` + 仪器测试；性能数字回填设计文档 §3.2。

## Open Questions

- `ENABLE_EDGEDRAWING=OFF` 在生产镜像中的默认策略（开发默认 ON，产品是否按需 OFF 待产品确认）
- Phase 4 Native I420 直通是否依赖 `MediaMetadataRetriever` YUV 平面 API 可用性（需真机验证）
- `ZeroPointManualAutoCoordinator` 拆分是否作为独立 change 以降低 Phase 3 风险
