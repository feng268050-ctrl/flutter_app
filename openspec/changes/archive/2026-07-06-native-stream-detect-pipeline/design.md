## Context

当前实时 RTSP 检测链路为：MediaMTX 中继 `rtsp://127.0.0.1:8554/camera/pr1` → Java 拉流/解码（`LivePr1InferenceStreamClient`、`EasyPlayerClient` + `getBitmap`）→ Java 抽帧 gate → JNI 传 I420 → C++ OpenCV/RKNN。`libai.so` 已有离线 NdkMediaCodec 写片与 `pushFrame` 入口，但**无** RTSP 实时拉流能力。

本 change 按 `docs/Native Stream Detection Pipeline.md` 将播放与检测拆为两条独立链路，分 Phase 0–4 落地，覆盖 lens_det、zero_point、edgedrawing 与 RKNN 流式路径。

## Goals / Non-Goals

**Goals:**

- C++ `StreamDetectPipeline` 独立消费 MediaMTX 本地 PR1，NdkMediaCodec 硬解（OutputBuffer），统一 NV12 → BGR/RGB，进程内调用现有检测逻辑
- Java 播放链路（`EasyPlayerClient` + Android MediaCodec）保持不变，仅订阅 C++ 发布的轻量检测事件
- 焊接场景（场景 B）先替换 `LivePr1InferenceStreamClient`；AI Vision（场景 A）后续双链路压测
- 实现 Pub-Sub（`StreamDetectResultBus`）与控制面 JNI（start/stop、laser、burst、模块开关）
- 对齐现有采样间隔：500ms 常态 / 100ms burst；RKNN 流式路径与 OpenCV 并行接入

**Non-Goals:**

- 不替换 Java UI 播放解码；不 bypass MediaMTX 直连 IPC
- 不改造离线 MP4（ExoPlayer + 文件/逐帧 JNI）
- 不在 Java ↔ C++ 之间传输图像帧
- 不合并播放与检测为单路解码

## Decisions

### 1. 双链路并行消费 PR1

**决策：** 播放（Java）与检测（C++）各开独立 RTSP 会话，均消费 `rtsp://127.0.0.1:8554/camera/pr1`。

**理由：** MediaMTX 支持多读者；职责分离使播放策略变更不影响检测，检测异常不影响 UI 流畅性。

**备选：** C++ 单路解码后向 Java 供帧 — 拒绝，仍耦合且 C++ 不适合 Surface 渲染。

### 2. C++ 硬解：NdkMediaCodec OutputBuffer + NV12 归一化

**决策：** 硬解使用 `NdkMediaCodec` OutputBuffer 模式（无 Surface 直出）；无论原始 `color-format` 为 NV12 或 I420，进检测前统一归一化为 NV12，再转 BGR（OpenCV）或 RGB（RKNN）。

**理由：** 与现有 `analyzeBgr` / detector 入口对齐；避免与 Java I420 回调格式耦合。

**备选：** 保持 I420 作为 C++ 中间格式 — 拒绝，硬解输出以 NV12 为主，统一 NV12 更简洁。

**软解回退：** FFmpeg demux + 软解输出 I420 时，经 libyuv 转 NV12 后再进检测，保持入口一致。

### 3. RTSP 栈：FFmpeg libavformat

**决策：** C++ 侧 RTSP 拉流与 demux 使用 FFmpeg（与工程现有 native 依赖一致），H.264/H.265 NAL 喂入 `NdkMediaCodec`。

**理由：** `libai.so` 无独立 RTSP 客户端；FFmpeg 成熟且项目已有集成基础。

**备选：** 自研 RTSP 客户端 — 成本高，无必要。

### 4. Java ↔ C++ 通信：Pub-Sub + 命令面 JNI

**决策：**

- **结果/状态（C++ → Java）：** 单一 JNI 上行回调 → `StreamDetectResultBus` 分发 `detect_result`、`pipeline_state`、`session_start|stop`、`error`
- **控制（Java → C++）：** 命令式 JNI：`startStreamDetect` / `stopStreamDetect`、`setLaserOn`、`setBurstMode`、模块 enable、ROI 路径

**理由：** 避免每个 Subscriber 各绑 native 回调；Coordinator 降级为 Subscriber，不再持帧。

**载荷：** 检测 JSON 字段遵循现有 `OPENCV_STAIN_DETECT_NATIVE_API.md`、`ZERO_POINT_NATIVE_API.md` 等；含 `timestampMs`、`frame_id`。

### 5. 抽帧与 burst 调度归属 C++

**决策：** live PR1 / AI Vision live 的 500ms / 100ms burst 抽帧由 C++ `StreamDetectPipeline` 内部调度；Java 在 burst 入口/退出时通过 `setBurstMode` 同步，或由 C++ 根据 `code=-5` 结果自行切换。

**理由：** 消除 Java gate 与 native 检测热路径耦合；与文档第八节业务状态机迁移建议一致。

**保留 Java gate：** 仅 process video（ExoPlayer 200ms）与离线路径不变。

### 6. 分阶段迁移顺序

| Phase | 内容 | 风险 |
|-------|------|------|
| 0 | 收敛 LivePr1 消费者、移除 getBitmap 检测、Java 路径基线 profile | 低 |
| 1 | 焊接：C++ 独占 PR1 解码取帧（可先 stub 检测，验证拉流+硬解） | 低 |
| 2 | 接入 lens_det / zero_point / edgedrawing + RKNN + Pub-Sub + Coordinator 改造 | 中 |
| 3 | AI Vision 双链路 + RK3566 压测 | 中高 |
| 4 | 同步、重连、可观测性、文档 | 低 |

Phase 1 可在检测 stub 下验收「拉流 + 硬解 + NV12 转换」；Phase 2 再接通算法与 Java 订阅。

### 7. RKNN 流式路径

**决策：** C++ 管线在 BGR/RGB `cv::Mat` 就绪后，按产品开关调用现有 RKNN 流式入口（等价于原 `guardedPushFrame` / `pushFrame` 进程内路径），结果同样经 Pub-Sub 发布。

**理由：** 用户确认 RKNN 纳入 scope；与 OpenCV 共享解码外壳，避免第二套拉流。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| AI Vision 双路 1080p 硬解 CPU/温升 | Phase 3 专项 RK3566 压测；不通过则 AI Vision 暂保留过渡方案，焊接仍走 C++ 单链路 |
| 播放与检测画面不同步 | 结果带 `timestampMs`/`frame_id`；UI 容忍 100–300ms；超时显示「检测中」 |
| C++ 流媒体栈从零建设 | Phase 1 先验收拉流+解码；断流重连 Phase 4 完善 |
| Coordinator 迁移遗漏 I420 引用 | Phase 0 统一 PR1 消费者清单；grep 验收 `FromI420` live 路径 |
| burst 状态机 Java/C++ 双写 | 单一权威：C++ 调度为主，Java 仅 laser ON/OFF 与会话启停 |

## Migration Plan

1. **Phase 0：** 审计并收敛 PR1 消费者；AI Vision 移除 getBitmap 检测；记录 Java 检测路径 baseline metrics。
2. **Phase 1：** 实现 `StreamDetectPipeline` 骨架 + JNI 控制面；焊接路径启动 C++ 会话替代 `LivePr1InferenceStreamClient`；保留 feature flag 可回退 Java 路径。
3. **Phase 2：** 接通 OpenCV/RKNN 检测 + `StreamDetectResultBus`；改造 Coordinator/SSE 为 Subscriber；删除 live PR1 JNI 传帧。
4. **Phase 3：** AI Vision 启用 C++ 检测订阅 + Java 播放并行；RK3566 验收 checklist。
5. **Phase 4：** 断流重连、性能统计、OpenSpec/集成文档更新；移除 feature flag 与废弃类。

**回滚：** Phase 1–2 保留 `LivePr1InferenceStreamClient` 代码路径至 feature flag 关闭；C++ pipeline stop 后 Java 可恢复旧链路。

## Open Questions

- C++ RTSP 重连 backoff 参数（初始间隔、最大重试）需在 Phase 4 实测后定稿。
- AI Vision 双链路不通过时的「过渡方案」具体行为（仅隐藏 overlay vs 回退 Java I420）在 Phase 3 压测后由产品确认。
