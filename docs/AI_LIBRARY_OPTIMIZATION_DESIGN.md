# AI 库文件结构与性能优化 — 方案设计

本文档汇总 `native/lensinspector`、`com.lasercyber.lws.ai` Java 层、`ai-library` 模型资产的**结构与热路径性能**优化方案（子包、环形缓冲、合并事件、巨型文件拆分等）。

> **进程边界（已切换）**：产品路径不再以进程内 `libai.so` + JNI 作为算法交互面。  
> 当前目标态是 **独立守护进程 `lws_ai_daemon` + Unix Domain Socket**（cmd/evt JSON Lines）。  
> **权威架构与 IPC 契约**见 [`ai-cpp-daemon-unix-socket-design.md`](ai-cpp-daemon-unix-socket-design.md)。  
> 本文优化项落在 daemon **进程内部**（以及 Java 子包 / UI 解耦）；验收时勿再按「App `System.load(libai)` / 直播 `nativeStartStreamDetect`」理解产品路径。

**相关文档**

- **进程 / IPC（权威）**：[`ai-cpp-daemon-unix-socket-design.md`](ai-cpp-daemon-unix-socket-design.md)
- Native 集成总览：[`OPENCV_DETECT_APP_INTEGRATION.md`](OPENCV_DETECT_APP_INTEGRATION.md)
- Stream detect 管线：[`Native Stream Detection Pipeline.md`](Native%20Stream%20Detection%20Pipeline.md)
- RKNN / lens-guard 对齐：[`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md)
- 推理计时开关：[`native/lensinspector/docs/LENS_INFER_TIMING.md`](../native/lensinspector/docs/LENS_INFER_TIMING.md)

**审查日期**：2026-07-10  
**边界对齐**：2026-07-14（与 daemon Unix socket 目标态对账）

---

## 1. 背景与范围

### 1.0 与 daemon 方案的关系

| 文档 | 回答的问题 | 产品主路径假设 |
|------|------------|----------------|
| **本文** | 算法与 Java 编排如何**分包、减拷贝、减事件分发开销** | 优化原始假设为同进程 JNI；落地后逻辑已迁入 **daemon 进程内**，Java 经 Supervisor 调用 |
| [`ai-cpp-daemon-unix-socket-design.md`](ai-cpp-daemon-unix-socket-design.md) | App 与算法如何**跨进程交互、生命周期、激光 Bit0 / AI 开关** | `AiDaemonSupervisor` ↔ `lws_ai_daemon`（abstract `@lws_ai_cmd` / `@lws_ai_evt`） |

OpenSpec：`openspec/changes/archive/2026-07-14-ai-cpp-daemon-unix-socket/`（P0–P3 已归档）。  
部署迭代：`make ai && make sync-ai`（推送 `liblws_ai_daemon.so` + 运行时 so，保留 `+x`）；含 Java/IPC 变更仍用 `make sync`。

### 1.1 什么是「AI 库」

本方案中的 AI 库指以下层次，而非单一目录：

| 层级 | 路径 | 规模（约） | 职责（当前） |
|------|------|-----------|-------------|
| Native 引擎 | `native/lensinspector/` | ~15k 行 C++ | 链进 **`lws_ai_daemon`**：StreamDetect、OpenCV lens-det、零点、可选 EdgeDrawing/RKNN |
| Java 编排 / IPC | `app/.../ai/`（含 `daemon/`） | 子包化后约 60+ 文件 | Supervisor + Coordinators + Bus；**非**产品路径加载 `libai` |
| UI 集成 | `ui/ai/`、`ui/common/ai/` | ~3k 行 | Overlay 映射、上传、离线视频会话 |
| 模型资产 | `ai-library/`（gitignored） | ~28MB 本地 | ONNX→RKNN 转换、校准集缓存 |
| 产物 | `app/src/main/jniLibs/arm64-v8a/` | **`liblws_ai_daemon.so`** + `librknnrt` / `libmpp` / `libc++_shared` | 打进 APK；可选 `AI_STAGE_LIBAI=1` 仅测试回滚 |

> 历史基线（审查时）：产物含进程内 `libai.so` ~11MB。daemon 切换后产品默认**不再**打必要 `libai.so`。

### 1.2 当前生产热路径

直播仍由 C++ `StreamDetectPipeline` 拉 PR1 RTSP，但运行在 **`lws_ai_daemon`** 进程；Java 只经 Unix socket 启停/配置/收事件。`RKNN_STAIN_INFER_ACTIVE` Java 推帧路径保持关闭。

```
App 冷启动
  └─ AiDaemonSupervisor → spawn lws_ai_daemon
       ├─ cmd: laser_state / ai_assist_config / configure_session
       │        stream_detect_start|stop / offline_infer_*
       └─ evt: heartbeat / combined_frame / detect_result / pipeline_state
            └─ StreamDetectResultBus (Java)
                 ├─ OpencvStainDetectCoordinator
                 └─ ZeroPointDetectCoordinator

daemon 内（原 libai 逻辑）:
  PR1 RTSP → StreamDetectPipeline
       ├─ lens_det / zero_point / （可选 rknn_stain）
       └─ 合并帧事件 → 写 evt.sock（不再走 App 进程内 JNI 回调）
```

审查时「合并每采样帧 JNI 回调」的目标，在 daemon 态对应为：**daemon 内仍合并模块结果，经 socket 一次发布**；App 侧不再 `CallVoidMethod` 进算法 so。

### 1.3 审查动机

- **文件结构**：Java 扁平大包、双架构残留、UI↔AI 循环依赖，增加维护与 onboarding 成本。
- **性能**：Native 帧路径多次 `cv::Mat::clone()`、RKNN 预处理/输出拷贝、每模块独立事件开销。
- **体积 / 隔离**：原 `libai.so` 与 UI 同进程；现由 daemon 二进制承载算法，可选模块裁剪与崩溃隔离见 daemon 文档。

---

## 2. 现状问题清单

### 2.1 文件结构

#### Java 层

| 问题 | 证据 | 影响 |
|------|------|------|
| 扁平大包 | `com.lasercyber.lws.ai` 无子包，56 文件混放 | 难以按域导航、职责边界模糊 |
| 上帝类 | `NativeBridge` 1389 行、`AiManager` 1376 行、`ZeroPointManualAutoCoordinator` 1371 行 | 单测困难、改动风险高 |
| 双架构残留 | `onBitmapFrame`、`tryAcceptOpencv*`、`tryAcceptRknn*` 无外部调用方；`RKNN_STAIN_INFER_ACTIVE=false` | 误导维护者以为 Java 推帧仍为主路径 |
| UI↔AI 循环依赖 | `ai/` 20+ 处 import `ui/`；`LensDetConsecutiveOkFilter` 引用 `ProcessVideoAiTimeline`；结果 DTO 依赖 `DetectionOverlayView` | 无法独立测试 AI 核心逻辑 |
| 重复模式 | 8+ 个 `getInstance()` Coordinator；`AiStainDetectCoordinator` 与 `OpencvStainDetectInferCoordinator` 相同 in-flight 门控 | 样板代码膨胀 |

#### Native 层

| 问题 | 证据 | 影响 |
|------|------|------|
| 命名误导 | `src/main.cpp` 实为 `CentralScheduler` 实现（1304 行） | onboarding 困惑 |
| CMake GLOB | `file(GLOB SOURCES src/*.cpp)` 自动收录新文件 | 易误链 test `main()` 进 `libai.so` |
| 重复编译 | `roi_config.cpp` 同时编入 `zero_point_core` 与 `edgedrawing_core` | so 内两份相同代码 |
| 硬依赖全模块 | `stream_detect_core` PUBLIC link 全部 detect core | 无法按需裁剪 EdgeDrawing 等 |
| 巨型源文件 | `scan_v_channel_radial_adaptive.cpp` 1635 行、`det_postprocess.cpp` 1116 行、`fixed_roi_pipeline.cpp` 1044 行 | 维护瓶颈 |
| JSON 序列化分散 | `det_callback_json`、`opencv_stain_detect_analyzer`、`stream_detect_pipeline` 等多处各自实现 | 行为不一致风险 |

#### 资产目录

| 问题 | 证据 | 影响 |
|------|------|------|
| `ai-library/` 无 README | 目录 gitignored，含 ONNX/RKNN + `_cache/calib/` | 新人不知哪些须本地准备、哪些是缓存 |

### 2.2 性能

| 优先级 | 问题 | 位置 | 影响 |
|--------|------|------|------|
| P0 | 三重 BGR 帧拷贝 | `main.cpp` pushFrame → waitFrame → trigger_check | 1920×1080 每帧 ~6MB 级内存带宽 |
| P0 | 双锁双缓冲 | `frame_mtx_`/`frame_buf_` + `frame_lock_`/`latest_frame_` | 每帧两次加锁 |
| P0 | 标量 NCHW 预处理 | `stain_preprocess::BgrToNchwFloat` | RKNN 推理前 CPU 热点 |
| P0 | RKNN 每轮 output memcpy | `rknn_runner.cpp` | 每次 infer dequant 到 `vector<float>` |
| P0 | 每模块一次 JNI 回调 | `stream_detect_event.cpp` | 每采样帧 N 次 `NewStringUTF` + `CallVoidMethod` |
| P1 | detached stain worker | `main.cpp` `std::thread(...).detach()` | shutdown 时潜在 UAF |
| P1 | 离线 Bitmap→NV12 CPU 转换 | `ProcessVideoAiSession` + `Nv12FrameUtil.fromBitmap` | 离线回放每 500ms 采样一次全帧转换 |
| P1 | `det_raw_concat` 每轮 alloc | `det_raw_concat.cpp` | 推理路径堆分配 |
| P1 | OpenCV pipeline 大量 `.clone()` | `fixed_roi_pipeline.cpp` 等 | debug 与 release 未隔离 |
| P2 | `libai.so` 11MB | 含全部模块 | APK 体积、冷启动 map 成本 |

### 2.3 已做得好的部分（保持不变）

- DirectByteBuffer 入帧（`GetDirectBufferAddress`），避免 `GetByteArrayElements` 拷贝。
- 嵌入式 RKNN 模型（objcopy → `.o`），无运行时文件 IO。
- Native 侧 500ms 采样，Java 不参与每帧调度。
- `RKNN_EXECUTOR` 单线程序列化 guarded JNI。
- `AiFrameSamplingGate` + `LensDetConsecutiveOkFilter` 时序过滤。

---

## 3. 目标

### 3.1 文件结构目标

1. Java `ai/` 按域划分子包，单文件控制在 **≤500 行**（桥接层例外可 ≤800 行）。
2. 清除或明确标注 Legacy Java 推帧路径，文档与代码只描述 StreamDetect 架构。
3. 打断 AI 核心与 UI View 的循环依赖；结果 DTO 使用纯几何类型。
4. Native 源文件按职责拆分；CMake 显式列表 + 可选模块编译开关。
5. 消除 `roi_config.cpp` 重复编译；`main.cpp` 重命名为 `central_scheduler.cpp`。

### 3.2 性能目标

| 指标 | 基线（估） | 目标 |
|------|-----------|------|
| 直播 stain 路径每帧 BGR 拷贝次数 | 3 次 | ≤1 次（swap 环形缓冲） |
| Stream detect 每采样帧 JNI 回调次数 | N（模块数） | 1（合并 JSON） |
| RKNN stain 预处理 | 标量循环 | OpenCV `blobFromImage` 或 NEON |
| 离线视频每采样帧 Java 颜色转换 | Bitmap→NV12 | 优先 native 直读或 I420 直通 |
| `libai.so` 体积（无 EdgeDrawing 构建） | 11MB | 待测，目标 −10~15% |

### 3.3 非目标

- 不重写 RKNN 模型或后处理算法逻辑（仅结构/拷贝优化）。
- 不在本方案内恢复 `RKNN_STAIN_INFER_ACTIVE` Java 推帧路径。
- 不拆分多个算法 `.so`（长期可选；**产品交互面**已由 [`ai-cpp-daemon-unix-socket-design.md`](ai-cpp-daemon-unix-socket-design.md) 收拢为 `lws_ai_daemon`，本文不做进程拆分设计）。

---

## 4. 方案设计

### 4.1 Java 包结构重组

```
com.lasercyber.lws.ai/
├── NativeBridge.java / Nv12FrameUtil.java   # 根保留：JNI 符号/测试回滚用；产品不 load libai
├── daemon/          AiDaemonSupervisor, AiDaemonSocketClient, AiDaemonBinary  ← 产品 IPC
├── bridge/          AiNativeRuntime, AiLibraryDirectory, AssetDeployer
├── engine/          AiManager（瘦身）, AiEngineConfigParser, AiEngineCapabilityProfile
├── stream/          NativeStreamDetectCoordinator（→ Supervisor cmds）,
│                    StreamDetectResultBus（evt 注入）, StreamDetectEvent, OverlayBridge…
├── stain/           OpencvStainDetectCoordinator, AiStainDetectCoordinator,
│                    *ResultMapper, LensDetConsecutiveOkFilter, LensStainBoxTemporalReducer…
├── zeropoint/       ZeroPointDetectCoordinator, ZeroPointManualAutoCoordinator（门面）
│                    + Workflow / LaserController / VideoAnalyzer / StageAggregate…
├── sampling/        AiFrameSamplingGate, AiFrameSamplingInterval, LiveInferGrace…
└── model/           NormalizedBox, AiStainDetectResult, OpencvStainDetectResult…
                     （无 DetectionOverlayView；映射在 ui/common/ai/overlay/）
```

**迁移原则**

- 每次 PR 只迁一个子包，保持 `import` 可通过 IDE 批量重构。
- 对外 API（`AiManager.getInstance()` 等）保持兼容，内部委托新类 / Supervisor。
- `ZeroPointManualAutoCoordinator` 拆为：
  - `ZeroPointManualAutoWorkflow`（状态机）
  - `ZeroPointLaserController`（Modbus / 激光）
  - `ZeroPointVideoAnalyzer`（离线视频采样）

### 4.2 Legacy 路径清理

| 动作 | 对象 | 说明 |
|------|------|------|
| 删除或 `@Deprecated` | `AiManager.onBitmapFrame` | 无调用方 |
| 删除或 `@Deprecated` | `tryAcceptOpencv*`、`tryAcceptRknn*` | 直播由 Native 采样 |
| 删除 | `Nv12FrameUtil.copyToDirectBuffer`、`i420DirectToNv12Direct`（若无调用方） | 减少 API 面 |
| 文档标注 | `RKNN_STAIN_INFER_ACTIVE` | 明确「保留供未来 RKNN 稳定后启用」 |
| 保留 | `opencvStainDetectFromNv12/Jpg` 一次性 API | 离线 process-video 仍用 |

### 4.3 UI 依赖解耦

```
Before:
  AiStainDetectResult → DetectionOverlayView.OverlayBox
  LensDetConsecutiveOkFilter → ProcessVideoAiTimeline

After:
  AiStainDetectResult → List<NormalizedBox>（x,y,w,h 0..1）
  DetectionOverlayView ← 映射层（ui/common/ai/overlay/）
  LensDetConsecutiveOkFilter → 接受 int sampleIndexMs 参数，不 import Timeline 类
```

### 4.4 Native 结构重组

#### 4.4.1 文件重命名与拆分

| 现文件 | 目标 |
|--------|------|
| `src/main.cpp` | `src/central_scheduler.cpp` + `src/central_scheduler.h`（从 `scheduler.h` 抽实现） |
| `src/jni_bridge.cpp` | `src/jni/rknn_jni.cpp`（可选，首期可只重命名 scheduler） |
| `scan_v_channel_radial_adaptive.cpp` | 拆为 `radial_scan_core.cpp` + `radial_scan_debug.cpp` |
| `det_postprocess.cpp` | 拆为 `det_decode.cpp` + `det_nms.cpp` |
| `fixed_roi_pipeline.cpp` | 按 stage 拆文件（`roi_crop`、`red_bright`、`halo_metrics` 已有部分独立） |

#### 4.4.2 CMake 改造

```cmake
# 1. roi_config 公共库
add_library(roi_config_common STATIC src/zero_point/roi_config.cpp)
target_link_libraries(zero_point_core PUBLIC roi_config_common)
target_link_libraries(edgedrawing_core PUBLIC roi_config_common)
# 从 zero_point_core / edgedrawing_core 源列表中移除 roi_config.cpp

# 2. 显式源文件列表（替代 GLOB）
set(AI_JNI_SOURCES
    src/jni_bridge.cpp
    src/opencv_stain_detect_jni.cpp
    src/zero_point_jni.cpp
    src/edgedrawing_jni.cpp
    src/stream_detect_jni.cpp
    src/central_scheduler.cpp
    ...
)

# 3. 可选模块
option(ENABLE_EDGEDRAWING "Include EdgeDrawing module in libai.so" ON)
option(ENABLE_RKNN_STAIN "Include RKNN stain in stream_detect" ON)
if(NOT ENABLE_EDGEDRAWING)
    # stream_detect_core 不 link edgedrawing_core
endif()
```

#### 4.4.3 共享 JSON 工具

新增 `src/opencv_detect/json_escape.h`（或扩展现有 `det_callback_json`），统一：

- 字符串转义
- `summaryJson` 嵌套序列化
- 错误码 → message 映射

各模块 `*_json.cpp` 调用公共 helper，避免行为漂移。

### 4.5 性能优化 — 帧缓冲（P0）

#### 现状

```
pushFrame:  NV12 → BGR → frame_buf_ (lock frame_mtx_)
waitFrame:  frame_buf_.clone() → out
run loop:   latest_frame_ = frame (lock frame_lock_)
trigger:    latest_frame_.clone() → worker_stain
```

#### 目标：双槽环形缓冲 + swap

```cpp
struct FrameSlot {
    cv::Mat bgr;          // 引用计数，无深拷贝
    int64_t pts_ms;
    std::atomic<bool> ready{false};
};

class FrameRingBuffer {
    FrameSlot slots_[2];
    std::atomic<int> write_idx_{0};
    std::mutex mtx_;      // 仅保护 idx 切换
public:
    void publish(cv::Mat bgr, int64_t pts);   // 写入下一槽，swap idx
    bool consume(cv::Mat& out, int64_t& pts); // 取最新 ready 槽，不 clone
};
```

**约束**

- `pushFrame` 仍在解码线程；`worker_stain` 在独立线程 — 双槽保证生产者不会覆盖消费者正在读的 Mat（OpenCV `cv::Mat` 引用计数安全）。
- stain worker 若需修改帧（画框），在 worker 内 `annotated = snap.clone()` 一次即可。

### 4.6 性能优化 — Stream Detect JNI 合并（P0）

#### 现状

每个启用的 detect 模块每采样帧各发一次 JNI：

```
publishDetectResult("lens_det", json1)
publishDetectResult("zero_point", json2)
```

#### 目标

单条合并事件：

```json
{
  "frame_pts_ms": 1500,
  "modules": {
    "lens_det": { ... },
    "zero_point": { ... }
  }
}
```

Java `StreamDetectResultBus` 解析后按 key 分发给已有 listener，**对外 Coordinator API 不变**。

Native 变更：

- `stream_detect_event.cpp`：累积当帧各模块结果，帧结束时一次 `publishStreamDetectEvent`。
- `StreamDetectNativeCallback` / `StreamDetectResultBus`：新增 `onCombinedFrame(String json)`，旧 per-module 回调标记 `@Deprecated` 后删除。

### 4.7 性能优化 — RKNN 预处理与输出（P0）

| 项 | 现状 | 改法 |
|----|------|------|
| BGR→NCHW | 双重 for 循环 | `cv::dnn::blobFromImage(roi, 1/255.0, Size(640,640), Scalar(), true, false, CV_32F)` |
| RKNN output | 每轮 `vector<float>` alloc | 成员 `output_buffers_` 复用；仅在 shape 变化时 resize |
| `det_raw_concat` | 每轮 `merged_raw` | `thread_local` 或成员 buffer 复用 |

验证：开启 `LENS_INFER_TIMING=ON` 构建，对比 `preprocess_ms` / `rknn_run_ms` / `postprocess_ms`。

### 4.8 性能优化 — 离线视频（P1）

`ProcessVideoAiSession` 当前路径：

```
MediaMetadataRetriever → Bitmap → Nv12FrameUtil.fromBitmap → nativeOpencvStainDetectFromNv12
```

优化选项（按侵入性递增）：

1. **短期**：`Nv12FrameUtil` 复用 direct buffer（session 级 `ByteBuffer` pool），避免每采样 `allocateDirect`。
2. **中期**：native 新增 `nativeOpencvStainDetectFromI420Direct`（与直播解码格式一致），Java 从 retriever 取 YUV 平面包。
3. **长期**：离线回放也走 `StreamDetectPipeline` 的 file/RTSP 输入模式，Java 只控时钟与 UI。

### 4.9 性能优化 — Stain Worker 生命周期（P1）

```cpp
// Before
std::thread([this, snap]{ worker_stain(snap); }).detach();

// After
class StainWorkerPool {
    std::thread worker_;
    std::mutex mtx_;
    std::condition_variable cv_;
    std::queue<cv::Mat> queue_;
    std::atomic<bool> stop_{false};
public:
    void submit(cv::Mat frame);
    void shutdown();  // drain + join
};
```

`CentralScheduler` 析构时 `shutdown()`，消除 detach UAF 风险。

### 4.10 `ai-library/` 目录规范

建议在仓库内增加 `ai-library/README.md`（可提交，目录本身仍 gitignore 内容）：

```markdown
# ai-library（本地，不提交二进制）

## 必需（make ai）
- det_raw_head.onnx — RKNN 转换输入

## 自动生成（勿提交）
- _cache/calib/ — 校准集解压缓存
- _cache/onnx2rknn/ — Docker 转换中间产物
- det_raw_head.rknn — 转换输出（会 cp 到 native/.../assets/models/）

## 命令
make ai                  # 完整：ONNX→RKNN + 编译 libai.so
SKIP_RKNN_CONVERT=1 make ai  # 跳过转换，用已有 .rknn
```

---

## 5. 分阶段落地计划

### Phase 0 — 文档与度量基线（0.5 周）

- [ ] 本文档评审通过
- [ ] `ai-library/README.md` 落地
- [ ] 真机采集基线：`LENS_INFER_TIMING=1 make ai` + logcat 记录 stain / stream detect 各阶段耗时
- [ ] 记录当前 `libai.so` 体积与 APK 总增量

### Phase 1 — 低风险清理（1 周）

| 任务 | 风险 | 验证 |
|------|------|------|
| 删除/标注 Legacy Java API | 低 | 全量编译 + 现有 unit test |
| `roi_config_common` 静态库 | 低 | `make ai` + `verify_libai_jni.sh` |
| `main.cpp` → `central_scheduler.cpp` 重命名 | 低 | 同上 |
| CMake 显式源文件列表 | 低 | CI `make ai` |

### Phase 2 — 性能 P0（1~2 周）

| 任务 | 风险 | 验证 |
|------|------|------|
| 帧环形缓冲去 clone | 中 | 对比 TIMING log；直播 stain 功能回归 |
| Stream detect 合并每帧事件 | 中 | Bus/单元测试 + 真机；产品路径计 **evt JSON Lines**，非 App JNI |
| RKNN 预处理改 `blobFromImage` | 中 | 与标量路径输出 diff（允许 FP 误差）；TIMING 对比 |
| RKNN output buffer 复用 | 低 | TIMING + 长时间稳定性 |

### Phase 3 — 结构重组（2~3 周，可并行多个 PR）

| 任务 | 风险 | 验证 |
|------|------|------|
| Java 子包迁移（按 §4.1 分批） | 中 | 每批 PR 独立编译 + 仪器测试 |
| 结果 DTO 去 UI 依赖 | 中 | Overlay 显示回归 |
| `ZeroPointManualAutoCoordinator` 拆分 | 高 | 手动零点自动校正全流程 |
| Native 巨型文件拆分 | 中 | `make ai` + host/offline CLI |
| `ENABLE_EDGEDRAWING` 编译开关 | 低 | 两种构建产物体积对比 |

### Phase 4 — 离线路径与长期项（按需）

- [ ] `ProcessVideoAiSession` ByteBuffer pool
- [ ] Native I420 直通离线 infer
- [ ] Stain worker 线程池 + 优雅 shutdown
- [ ] 评估拆分 `libai_opencv.so` / `libai_rknn.so`（仅当 APK 体积成为硬性指标）

---

## 6. 风险与回退

| 风险 | 缓解 | 回退 |
|------|------|------|
| 帧缓冲 swap 引入竞态 | 双槽 + 引用计数；仪器测试长时间直播 | 恢复 `clone()` 路径（单开关 `LWS_FRAME_RING_BUFFER`） |
| `blobFromImage` 数值与标量路径不一致 | 离线对比脚本；容差阈值测试 | CMake 选项保留标量实现 |
| 合并每帧事件破坏下游 | Bus 适配层保持 per-module listener；evt 载荷对齐旧 JSON | 保留旧分支一个版本；daemon 短命回滚见 `AI_STAGE_LIBAI` |
| Java 子包迁移 import 遗漏 | 分批 PR；CI 全编译 | Git revert 单批 |
| `ENABLE_EDGEDRAWING=OFF` 漏符号 | `verify_libai_jni.sh` / daemon 构建配置检查 | 默认 ON |

---

## 7. 验收标准

### 7.1 结构

- [ ] `com.lasercyber.lws.ai` 至少 5 个子包（含 `daemon/`），无单文件 >1500 行
- [ ] `ai/` 包不 import 任何 `ui.*.view` 或 `Fragment`（bridge 层除外可映射）
- [ ] CMake 无 `file(GLOB src/*.cpp)` 编入 daemon / 核心静态库
- [ ] `roi_config.cpp` 只编译一次（`roi_config_common`）
- [x] 产品路径不 `System.load(libai.so)`；算法经 `AiDaemonSupervisor`（见 daemon 文档 §10）

### 7.2 性能

- [ ] `LENS_INFER_TIMING` 报告 stain 路径 `frame_copy_ms` 下降 ≥50%（或该项归零；在 **daemon 进程** logcat）
- [ ] Stream detect 每采样帧对外 **一次** 合并事件（daemon 内合并 → evt；非 App 侧 N 次 JNI）
- [ ] 直播 AI Vision + 焊接 stain/零点功能仪器测试通过（含 Bit0 / Supervisor，见 daemon §10）
- [ ] 离线 process-video 推理结果与优化前 bbox 一致（IoU ≥0.95）

### 7.3 体积（可选构建）

- [ ] `ENABLE_EDGEDRAWING=OFF` 构建 daemon / 相关静态库体积减小可测量

---

## 8. 附录

### 8.1 关键文件索引

| 域 | 文件 |
|----|------|
| Daemon 入口 / IPC | `native/lensinspector/src/daemon/*`、`app/.../ai/daemon/AiDaemonSupervisor.java` |
| Native 调度 | `native/lensinspector/src/central_scheduler.cpp` |
| Native 帧事件 | `native/lensinspector/src/stream_detect/stream_detect_event.cpp` |
| RKNN | `native/lensinspector/src/rknn_runner.cpp`、`stain_preprocess.cpp` |
| Postprocess | `cpp/postprocess/det_decode.cpp`、`det_nms.cpp` |
| Java 入口 | `app/.../ai/engine/AiManager.java`、`LaserApplication`（冷启动 Supervisor） |
| Java 直播 | `app/.../ai/stream/NativeStreamDetectCoordinator.java`、`StreamDetectResultBus.java` |
| Java 离线 | `app/.../ui/common/ai/video/ProcessVideoAiSession.java` → Supervisor `offline_infer_*` |
| Overlay 映射 | `app/.../ui/common/ai/overlay/DetectionOverlayMapper.java` |
| 构建 / 同步 | `scripts/make/build-ai.sh`、`scripts/ci/sync-ai.sh`、`native/lensinspector/CMakeLists.txt` |

### 8.2 架构对照（优化 + daemon 目标态）

```
┌─────────────────────────────────────────────────────────────┐
│  UI Layer (AiVisionFragment, overlays, upload)              │
│    ↕ NormalizedBox / OverlayMapper / 业务事件                │
├─────────────────────────────────────────────────────────────┤
│  ai/daemon  Supervisor + socket (cmd + evt)                 │
│  ai/stream  ai/stain  ai/zeropoint  ai/sampling  ai/model   │
│    ↕ AF_UNIX JSON Lines（产品路径）                          │
├─────────────────────────────────────────────────────────────┤
│  lws_ai_daemon（进程）                                       │
│  ├─ stream_detect_core (RTSP → decode → schedule)           │
│  ├─ opencv_stain_detect_core  (+ fixed_roi_* 拆分)          │
│  ├─ zero_point_core ← roi_config_common →                   │
│  ├─ edgedrawing_core (可选 ENABLE_EDGEDRAWING)              │
│  ├─ central_scheduler + FrameRingBuffer + StainWorkerPool   │
│  ├─ rknn_runner / stain_preprocess（可选）                  │
│  └─ yolo_postprocess (det_decode + det_nms)                 │
└─────────────────────────────────────────────────────────────┘
```

---

**文档维护**：各 Phase 完成后更新 §7 checklist；性能数字回填 §3.2。进程/IPC 变更只改 [`ai-cpp-daemon-unix-socket-design.md`](ai-cpp-daemon-unix-socket-design.md)，本文仅交叉引用。
