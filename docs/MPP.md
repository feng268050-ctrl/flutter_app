# StreamDetect 视频基础链路与 OS 无关 C++ 推理架构

> **OpenSpec：** [`native-stream-detect-pipeline`](../openspec/specs/native-stream-detect-pipeline/spec.md)  
> **Java 集成：** [`stream-detect-result-bus`](../openspec/specs/stream-detect-result-bus/spec.md)  
> **产品背景：** [`Native Stream Detection Pipeline.md`](./Native%20Stream%20Detection%20Pipeline.md)

本文描述 **live PR1** 检测在 C++ 侧的视频基础链路与推理分层，目标是：

> **C++ 推理核心（拉流 → 解码契约 → 调度 → OpenCV/RKNN 检测）完全不依赖操作系统；Android / Linux 差异仅存在于可替换的 platform backend 与极薄的 JNI 适配层。**

Java 负责 **UI 播放（Android `MediaCodec` 硬解 → Surface/TextureView）、业务编排、控制面命令、结果订阅**；**不得**再向 live 检测路径传递 YUV/Bitmap 图像帧。

C++ 检测链路负责 **独立拉流 → Rockchip MPP 硬解 → NV12 → BGR/RGB → 算法**；**不得**依赖 Android `MediaCodec` / `NdkMediaCodec` 或 Java 解码回调。**I420 已遗弃**，全栈 YUV 契约统一为 **NV12**。

---

## 1. 与 OpenSpec 的对齐关系

| OpenSpec 要求 | 本文档章节 | 实现状态（Frame-extraction） |
|---------------|-----------|------------------------------|
| 独立消费 MediaMTX PR1 | §2、§4 | ✅ `RtspTcpSession` → `rtsp://127.0.0.1:8554/camera/pr1` |
| **MPP 硬解 → NV12 归一化**（C++ 不依赖 OS 解码） | §4、§8、§11 | ✅ `IVideoDecoder` + `MppVideoDecoder`；RK3566 产品镜像 `ENABLE_ROCKCHIP_MPP=ON`；模拟器 Ndk fallback |
| 500 ms / 100 ms burst  native 调度 | §9 | ✅ `FrameScheduler` |
| 进程内 OpenCV / zero_point / edgedrawing | §9 | ✅ `detect_runner` |
| 可选 RKNN streaming | §9 | ✅ 产品开关控制 |
| 禁止 live JNI 传图 | §10 | ✅ Coordinator 订阅 bus |
| 轻量事件 uplink + 控制面 JNI | §10 | ✅ `stream_detect_event` + `NativeBridge` |
| 断流 reconnect + backoff | §9 | ✅ `StreamDetectPipeline::workerLoop` |
| Java 播放：Android MediaCodec 硬解 | §10 | ✅ `EasyPlayerClient`（仅播放，不参与检测） |

**不在本文范围：** 离线工艺视频（`ProcessVideoAiSession` / `Nv12FrameUtil`）见 [`offline-inference-nv12`](../openspec/specs/offline-inference-nv12/spec.md) 与 `OPENCV_DETECT_APP_INTEGRATION.md`。

---

## 2. 三层边界（OS 无关核心）

```text
┌─────────────────────────────────────────────────────────────┐
│  Java 壳层（Android Framework — 仅播放与业务）                  │
│  EasyPlayerClient + Android MediaCodec 硬解 → Surface/Texture │
│  StreamDetectResultBus 订阅 │ 控制面 JNI                      │
│  ▲ 仅 JSON 事件上行；不传 YUV / Bitmap                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ thin JNI adapter（platform/android）
                           │  stream_detect_jni.cpp
┌──────────────────────────▼──────────────────────────────────┐
│  C++ 推理核心（OS 无关，可单元测试 / Linux 复用）              │
│  StreamDetectPipeline · FrameScheduler · detect_runner       │
│  vision: opencv_stain_detect · zero_point · edgedrawing      │
│  可选 RKNN adapter（BGR→RGB 在 adapter 内，不在视频层）        │
│  便携 RTSP/RTP/H.264 AU · DecodedFrame(NV12) · IFrameConverter │
└──────────────────────────┬──────────────────────────────────┘
                           │ IVideoDecoder · IFrameConverter
┌──────────────────────────▼──────────────────────────────────┐
│  Platform backend — C++ 检测专用（Rockchip，非 OS 解码 API）   │
│  MppDecoder（H.264/H.265 硬解 → NV12）                        │
│  RgaConverter / yuv_convert（NV12 → BGR，stride-aware）       │
└─────────────────────────────────────────────────────────────┘
```

**原则：**

1. **`StreamDetectPipeline` 及下游算法不得 `#include` Android NDK / JNI / MediaCodec 头文件。**
2. **C++ 检测解码 MUST 走 Rockchip MPP**，输出 **NV12**；**禁止**在检测链路使用 `NdkMediaCodec`、Java `MediaCodec` 或 **I420** 作为 YUV 契约。
3. **Java `MediaCodec` 仅用于 UI 播放**（`EasyPlayerClient`）；播放解码与检测解码是**两条独立 RTSP 会话**，互不传帧。
4. **解码、硬件色彩转换** 通过 **`IVideoDecoder` / `IFrameConverter`** 注入；便携默认 `nv12ToBgr`（`yuv_convert.cpp`）。
5. **JNI 只做** 控制命令下行 + JSON 事件上行；**不属于** 推理核心。
6. **算法统一入口为 `cv::Mat` BGR**（OpenCV）；RKNN 在独立 adapter 内做 BGR→RGB，视频层不混出 RGB。

---

## 3. 端到端链路（live PR1）

与 OpenSpec 及当前代码一致：

```text
IPC PR1
    ↓
MediaMTX  relay  rtsp://127.0.0.1:8554/camera/pr1
    ↓
══════════════════ C++ 推理核心（OS 无关）══════════════════
RtspTcpSession          ← 自研 RTSP/TCP + RTP/H.264（无 Java）
    ↓
Annex-B Access Unit
    ↓
IVideoDecoder           ← platform: **MppDecoder**（Rockchip MPP）
    ↓
DecodedFrame            ← **NV12** + stride（见 §7；I420 已遗弃）
    ↓
IFrameConverter         ← RGA 或 portable `nv12ToBgr`
    ↓
cv::Mat BGR
══════════════════ 视频层 / 算法层边界 ══════════════════
FrameScheduler          ← 500 ms 正常 / 100 ms burst；激光门控
    ↓
detect_runner           ← in-process，无 JNI 传图
    ├── lens_det        analyzeOpencvStainDetectBgr
    ├── zero_point      detectBgr
    ├── edgedrawing     detectBgr
    └── rknn（可选）     BgrToRgbAdapter → native streaming
    ↓
stream_detect_event     ← detect_result / pipeline_state / …
══════════════════════════════════════════════════════════
    ↓
StreamDetectResultBus   ← Java 订阅；Overlay / Coordinator / SSE
EasyPlayerClient        ← 独立 RTSP 会话；**Android MediaCodec 硬解，仅播放**
```

**双读者：** 检测与播放各开 **独立 RTSP 会话** 消费 `camera/pr1`（OpenSpec：播放断流不影响检测，反之通过 `pipeline_state` 上报）。

**YUV 契约：** App / JNI / 离线抽帧 / live 检测统一 **NV12**；legacy 解码器若输出 planar YUV，仅在 ingress 一次性转为 NV12（`Nv12FrameUtil.i420DirectToNv12Direct` / native `i420ToNv12`），**不得**再作为产品主路径或 JNI 符号。

---

## 4. 当前代码映射

| 目标模块（OS 无关） | 当前路径 | 备注 |
|--------------------|----------|------|
| Pipeline + 调度 | `stream_detect/stream_detect_pipeline.cpp` | worker 线程：decode → schedule → detect |
| 调度器 | `stream_detect/frame_scheduler.cpp` | burst / 500 ms |
| 检测编排 | `stream_detect/detect_runner.cpp` | 模块 enable 由 `SessionConfig` |
| 便携色彩 | `stream_detect/yuv_convert.{h,cpp}` | `nv12ToBgr`（**I420 已遗弃**） |
| RTSP 源（耦合态） | `stream_detect/rtsp_demux.{h,cpp}` | **待拆**为 Source + Decoder + Converter |
| RTSP/TCP | `stream_detect/rtsp_tcp_session.*` | 可保留在 core |
| Platform 解码 | `platform/rockchip/mpp_video_decoder.*` + `video_decoder_factory` | MPP 优先；Ndk 过渡 fallback |
| Platform 解码（过渡） | `platform/android/ndk_media_codec_video_decoder.*` | 仅 `ENABLE_STREAM_DETECT_NDK_FALLBACK` |
| JNI 适配 | `stream_detect_jni.cpp` | 仅桥接，非推理 |
| Vision | `opencv_stain_detect/`, `zero_point/`, `edgedrawing/` | 已是 BGR 入口 |

**目标硬解主路径（`rtsp_demux` / `MppDecoder`）：**

```text
readNextAccessUnit → MppDecoder::queueAccessUnit
                  → dequeueOutput(NV12)
                  → nv12ToBgr → cv::Mat
```

> **过渡态说明：** 当前 `Frame-extraction` 分支仍可能链接 `MediaCodecDecoder`（`NdkMediaCodec`）作为临时 backend；架构与 OpenSpec 演进方向是 **MPP → NV12**，与 Java 播放侧的 Android `MediaCodec` **严格分离**。新代码不得扩大 OS 解码在 C++ 检测链路上的依赖。

---

## 5. 为什么算法边界是 BGR

OpenCV 检测需要 **HSV / 颜色判断 / CLAHE(V)**，视频层若只输出 Y/Gray 会丢失 chroma。

```text
视频层职责（到 BGR 为止）：
  RTSP · 解码 · NV12 归一化 · 色彩 → cv::Mat CV_8UC3 BGR

算法层职责（BGR 之后）：
  ROI · BGR↔HSV · CLAHE · 灰度 · 阈值 · 形态学 · 连通域 · 判据
```

同一 BGR 帧分叉为「亮度增强链路」与「颜色检测链路」，均在 `opencv_stain_detect` 等模块内部完成。**视频层不得做 HSV/CLAHE/Threshold。**

---

## 6. 目标目录结构（OS 无关 core + platform）

```text
native/lensinspector/src/
├── stream_detect/              # 推理核心（禁止 Android 头文件）
│   ├── stream_detect_pipeline.*
│   ├── frame_scheduler.*
│   ├── detect_runner.*
│   ├── rtsp_tcp_session.*      # 便携网络栈
│   ├── rtp_depacketizer.*      # 从 rtsp_demux 拆出（计划）
│   ├── h264_au_builder.*       # 计划
│   ├── decoded_frame.h         # 计划
│   ├── ivideo_decoder.h        # 计划
│   ├── iframe_converter.h      # 计划
│   └── yuv_convert.*           # portable NV12→BGR
│
├── platform/
│   ├── android/
│   │   └── stream_detect_jni.cpp   # JNI only；不含 OS 解码
│   └── rockchip/               # C++ 检测 backend（RK3566）
│       ├── mpp_decoder.*       # H.264/H.265 → NV12
│       └── rga_converter.*     # NV12 → BGR
│
└── vision/                     # 现有 opencv_stain / zero_point / edgedrawing
```

**链接关系：** `libai.so` 在 Android 上链接 `platform/android`（JNI）+ `platform/rockchip`（MPP/RGA）；Linux 推理二进制同样链接 `platform/rockchip`，**core 与 vision 目标文件相同**。

---

## 7. DecodedFrame 契约（禁止裸 NV12 假设）

OpenSpec 要求解码输出 **NV12** 再转 BGR；实现上不得假设 `stride == width`、无 padding。**I420 已遗弃**，`DecodedFrame` 产品契约仅 **NV12**。

```cpp
enum class PixelFormat { NV12, NV21, Unknown };

struct DecodedFrame {
    std::vector<uint8_t> data;
    int width = 0;
    int height = 0;
    int stride = 0;
    int slice_height = 0;
    PixelFormat format = PixelFormat::Unknown;  // 检测链路期望 NV12
    int64_t pts_us = 0;
};
```

```text
IVideoDecoder::receiveFrame(DecodedFrame&)   // MPP → NV12
        ↓
IFrameConverter::toBgr(const DecodedFrame&, cv::Mat& bgrOut)
```

目标 `MppDecoder` 输出 stride-aware NV12；过渡态 `MediaCodecDecoder` 须尽快替换，不得作为长期架构依赖。

---

## 8. 色彩转换与 NV12 归一化

| 阶段 | 契约 | 实现 |
|------|------|------|
| MPP 硬解输出 | **NV12**（stride-aware） | `MppDecoder`（目标） |
| 色彩转换 | NV12 → **BGR** | `RgaConverter` 或 `nv12ToBgr` |
| OpenCV 检测 | **BGR** `cv::Mat` | `analyzeOpencvStainDetectBgr` |
| RKNN（可选） | BGR 就绪后 **adapter 内** BGR→RGB | 视频层不输出 RGB |

**Portable 默认：** OpenCV `COLOR_YUV2BGR_NV12`（`yuv_convert.cpp`），与 live / offline JNI 共用。

**Linux / Android RK3566：** `MppDecoder` + `RgaConverter` 为 C++ 检测链标准 backend；**禁止**用 Android `NdkMediaCodec` 替代 MPP 作为检测解码长期方案。

---

## 9. 调度、检测与重连（OpenSpec 行为）

### 9.1 帧采样（native 内）

| 模式 | 间隔 | 触发 |
|------|------|------|
| 正常 | **500 ms** | live weld / zero_point（`LIVE_WELD`, `ZERO_POINT_ON_LASER`） |
| Burst | **100 ms** | native `code=-5` 后（`FRAME_REJECTED_BURST`） |

解码可全帧率运行；**仅 gated 样本** 调用 `detect_runner`。激光 OFF → 停止调度并重置 burst（Java `setLaserOn(false)`）。

### 9.2 进程内检测（无 JNI 传图）

```cpp
runEnabledDetectModules(bgr, config, frame_id);
// → publish detect_result JSON（含 timestampMs, frame_id, module）
```

Live 路径 **禁止** Java 向 native 传递 YUV 帧；**禁止** `nativeOpencv*FromI420` / `I420DataCallback` 喂 PR1 检测。

### 9.3 断流重连

`StreamDetectPipeline::workerLoop`：连续读失败 → bounded backoff reconnect → `pipeline_state` 事件；`stopStreamDetect` 取消重连 loop。

### 9.4 线程模型

**当前（OpenCV-only 足够）：** 单 worker — read → schedule → detect → next。

**后续（算法变重 / RKNN / 积压）：** Thread-1 解码写入 `LatestFrameSlot`；Thread-2 调度取最新 BGR。实时检测 **不用** 无限增长帧队列。

---

## 10. Java 边界（播放 vs 检测）

Java **不参与** C++ 检测链路的拉流、解码与色彩转换。

| 职责 | 机制 | 说明 |
|------|------|------|
| **播放** | `EasyPlayerClient` + **Android `MediaCodec` 硬解** | 独立 PR1 RTSP 会话 → Surface/TextureView；**仅 UI 预览** |
| 下行控制 | Command JNI | `startStreamDetect` / `stopStreamDetect`, `setLaserOn`, `setBurstMode`, 模块 enable |
| 上行结果 | 单 JNI callback → `StreamDetectResultBus` | `detect_result`, `pipeline_state`, `session_start`/`stop`, `error` |

**禁止：** uplink 传 raw YUV / Bitmap；Subscriber 在 native 回调线程做 Modbus/SSE/UI（须 dispatch 到 executor）；用 `I420DataCallback` 或 `getBitmap` 喂 live 检测。

详见 OpenSpec `stream-detect-result-bus`。

---

## 11. Platform Backend（C++ 检测专用）

### 11.1 Java 播放（Android OS 解码 — 允许）

```text
EasyPlayerClient → Android MediaCodec 硬解 → Surface / TextureView
```

播放链路**可以且应当**使用 Android 系统 `MediaCodec`；与 C++ 检测 **无帧级耦合**。

### 11.2 C++ 检测（Rockchip MPP — 必选，非 OS 解码）

```text
IVideoDecoder → MppDecoder      # Rockchip MPP 硬解 H.264/H.265 → NV12
IFrameConverter → RgaConverter  # NV12 → BGR（stride/padding 由 RGA 或 portable 处理）
```

```text
RTSP PR1
    ↓
C++ RTSP TCP Session
    ↓
RTP Depacketizer
    ↓
H.264 Access Unit
    ↓
MPP Hardware Decoder          ← 不用 NdkMediaCodec / Java MediaCodec
    ↓
NV12 DecodedFrame（stride-aware）
    ↓
RGA / nv12ToBgr
    ↓
cv::Mat BGR
════════════════════════
算法层边界（与平台无关）
════════════════════════
    ↓
OpenCV / RKNN Algorithm
```

**替换 backend 时，`StreamDetectPipeline` / `detect_runner` / OpenCV 模块零修改。**

> **过渡态：** 仓库中若仍存在 `media_codec_decoder.*`（`NdkMediaCodec`），视为 **MPP 落地前的临时实现**，不得写入 normative 架构；文档与 OpenSpec 以 **MPP → NV12** 为准。

---

## 12. 重构阶段

### 阶段 A — 已交付（native-stream-detect-pipeline）

- `StreamDetectPipeline` 独立 PR1 + in-process detect + event bus
- 焊接 live 常开；Java 不传 live 图像帧
- NV12 契约 + portable `nv12ToBgr`；**I420 JNI 已移除**

### 阶段 B — OS 解耦 + MPP backend（本文目标）

1. 引入 `DecodedFrame` / `IVideoDecoder` / `IFrameConverter` 接口  
2. **`MppDecoder` + `RgaConverter`** 替换 `media_codec_decoder.*`（`NdkMediaCodec` 过渡代码）  
3. 拆分 `RtspDemux` → `RtspTcpSession` + depay + AU builder + `IBgrFrameSource`  
4. `StreamDetectPipeline` 只依赖 `IBgrFrameSource`，不感知 MPP/JNI/MediaCodec  

### 阶段 C — Linux 产线 / 台架

1. 同一 `platform/rockchip` 链接为 Linux 推理进程（无 JNI；事件可走 stdout/IPC 替代 bus）  
2. 与 Android RK3566 产品共用 MPP → NV12 → BGR 路径  

---

## 13. 结论

1. **OpenSpec `native-stream-detect-pipeline` 定义的产品行为**（独立 PR1、NV12、native 调度、in-process 检测、JSON 事件、控制面）为 normative；本文描述 **如何用 OS 无关分层 + MPP backend 去实现与演进**。
2. **C++ 推理核心** = 便携 RTSP + **NV12** `DecodedFrame` 契约 + 调度 + `detect_runner` + vision（+ 可选 RKNN adapter）；**不依赖** Android/Linux OS 解码 API。
3. **Java 播放** = `EasyPlayerClient` + **Android MediaCodec**（允许 OS 依赖）；**C++ 检测** = **MPP → NV12 → BGR**（Rockchip backend）。
4. **I420 已遗弃**；ingress 若遇 legacy planar YUV，仅一次性转 NV12，不作为 JNI/文档主契约。
5. **算法边界** = `cv::Mat` **BGR**；HSV/CLAHE/形态学留在 OpenCV 模块内。
6. **下一步工程重点**：落地 `MppDecoder`，移除 C++ 检测链对 `NdkMediaCodec` 的过渡依赖。

---

## 14. 相关文档

| 文档 | 用途 |
|------|------|
| [`openspec/specs/native-stream-detect-pipeline/spec.md`](../openspec/specs/native-stream-detect-pipeline/spec.md) | 需求规格 |
| [`openspec/specs/stream-detect-result-bus/spec.md`](../openspec/specs/stream-detect-result-bus/spec.md) | Java 事件与控制面 |
| [`Native Stream Detection Pipeline.md`](./Native%20Stream%20Detection%20Pipeline.md) | 产品背景与 Phase 历史 |
| [`OPENCV_DETECT_APP_INTEGRATION.md`](./OPENCV_DETECT_APP_INTEGRATION.md) | App 六层集成 checklist |
| [`openspec/specs/offline-inference-nv12/spec.md`](../openspec/specs/offline-inference-nv12/spec.md) | 离线 NV12（非 RTSP） |
