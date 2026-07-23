## Why

实时 RTSP 检测当前依赖 Java 拉流、解码、抽帧，再通过 JNI 将 I420 图像帧传给 C++ 检测。该链路使检测与 Java 播放/解码强耦合，每帧带来约 3MB 内存拷贝与 JNI 调度开销，且 `LivePr1InferenceStreamClient`、AI Vision `getBitmap` 等多套 Java 检测解码并存，职责边界不清。本 change 将播放解码与检测解码拆成两条独立链路：Java 继续负责 UI 播放，C++ 独立接入 MediaMTX 本地 PR1 子流做 native 硬解与检测，以发布-订阅模式推送轻量结果，消除 JNI 图像帧传输。

## What Changes

- **新增** C++ `StreamDetectPipeline`：独立拉取 `rtsp://127.0.0.1:8554/camera/pr1`，NdkMediaCodec 硬解（OutputBuffer 模式），统一归一化为 NV12 → BGR/RGB，进程内调用现有 OpenCV / RKNN 检测逻辑
- **新增** JNI 事件桥与 Java `StreamDetectResultBus`：C++ 发布 `detect_result` / `pipeline_state` / `session_start|stop` / `error`；Java 订阅方（Overlay、Coordinator、SSE）只消费轻量事件，不传图像帧
- **新增** Java → C++ 控制面 JNI：`start` / `stop`、`setLaserOn`、`setBurstMode`、模块开关与 ROI 配置
- **Phase 0** 收敛现状：统一 PR1 消费者、移除 AI Vision `getBitmap` 低效检测路径、建立 Java 检测路径性能基线
- **Phase 1** 焊接路径：下线 `LivePr1InferenceStreamClient` 检测解码，C++ 独占 PR1 检测链路；PR0 录制与 Java 播放不受影响
- **Phase 2** 接入全部检测模块（lens_det、zero_point、edgedrawing）与 RKNN 流式路径；Coordinator 降级为 Subscriber + 业务编排，不再持有 I420 帧
- **Phase 3** AI Vision 双链路：Java `EasyPlayerClient` 硬解播放 PR1 与 C++ 并行检测同一条流；RK3566 压测 CPU/温升/overlay 同步
- **Phase 4** 稳定性与可观测性：`timestampMs` / `frame_id`、结果超时、断流重连、性能统计、文档与 OpenSpec 同步
- **明确不改造** 离线 MP4（ExoPlayer + 文件/逐帧 JNI）路径
- **BREAKING**（规格层）：`production-ai-inference-stream-lifecycle`、`lens-det-app-inference`、`zero-point-detect-on-laser-on` 等 live PR1 I420 驱动检测的要求将改为 C++ 管线发布-订阅驱动

## Capabilities

### New Capabilities

- `native-stream-detect-pipeline`: C++ 侧 RTSP 拉流、NdkMediaCodec 硬解、NV12 归一化、抽帧调度、OpenCV/RKNN 进程内检测、断流重连与结果发布
- `stream-detect-result-bus`: Java 侧统一订阅 C++ 检测事件（detect_result、pipeline_state、session、error），供 Overlay、Coordinator、SSE 等消费

### Modified Capabilities

- `production-ai-inference-stream-lifecycle`: 焊接模式检测生命周期由 `LivePr1InferenceStreamClient` 改为 C++ `StreamDetectPipeline` 会话启停
- `lens-det-app-inference`: live weld / AI Vision live 检测由 Java I420 采样 + `opencvStainDetectFromI420` 改为订阅 C++ `detect_result`
- `zero-point-detect-on-laser-on`: PR1 驱动零点检测由 Java I420 快照改为 C++ 管线内调度 + 结果订阅
- `laser-detect-frame-rejected-burst`: burst 采样（code=-5 → 100ms）由 Java gate 迁移至 C++ 调度器或 Java 控制信号 + C++ 执行
- `device-local-http-ai-inference-sse`: `CameraAiHttpPublisher` 作为 Subscriber 消费 C++ 发布事件，不再依赖 Java 解码回调触发 SSE
- `ai-frame-sampling-inference`: live PR1 / AI Vision live 的抽帧 gate 从 Java 侧迁移至 C++ 管线（process video 离线路径保持 Java）
- `ai-vision-live-resolution-profile`: AI Vision 场景改为 Java 播放 + C++ 检测双链路并行消费 PR1

## Impact

- **C++ / libai.so**: 新增 RTSP 客户端、实时 NdkMediaCodec 解码、NV12 色彩转换、StreamDetectPipeline 调度与 JNI 事件桥；复用现有 `analyzeBgr` / opencv_stain_detect / zero_point / edgedrawing / RKNN 入口
- **Java**: 下线或废弃 `LivePr1InferenceStreamClient` 检测用途；`OpencvStainDetectCoordinator`、`ZeroPointManualAutoCoordinator`、`LaserDetectSamplingCoordinator` 改为 Subscriber；新增 `StreamDetectResultBus` 与控制面 JNI 封装
- **AI Vision**: `AiVisionFragment` 移除 `TextureView.getBitmap` 检测路径；保留 `EasyPlayerClient` 播放，订阅 C++ 检测结果叠加
- **MediaMTX**: 检测与播放各开独立 RTSP 会话消费 `camera/pr1`（AI Vision 双读者场景）
- **规格与文档**: 更新 `OPENCV_DETECT_APP_INTEGRATION.md`、相关 Native API 文档；离线 MP4 / ExoPlayer 路径不变
