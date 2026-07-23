## 1. Phase 0 — 收敛现状与基线

- [x] 1.1 审计所有 PR1 消费者（`LivePr1InferenceStreamClient`、`LensGuardManager.onI420Frame`、AI Vision `getBitmap`、手动零点采样等），输出清单与收敛计划
- [x] 1.2 统一焊接路径 PR1 消费者入口，避免多处独立创建 `LivePr1InferenceStreamClient`
- [x] 1.3 移除或禁用 AI Vision live 路径上 `TextureView.getBitmap` 喂检测的低效实现（保留播放）
- [x] 1.4 在 RK3566 上 profile 当前 Java 检测路径基线（解码 ms、JNI 拷贝、检测 ms、端到端 ms）并记录对比数据

## 2. Phase 1 — C++ 管线骨架与焊接路径替换

- [x] 2.1 在 `libai.so` 新增 `StreamDetectPipeline` 模块目录结构（RTSP demux、decode、convert、scheduler、event publisher）
- [x] 2.2 实现 FFmpeg RTSP 拉流 + demux，H.264/H.265 NAL 喂入 `NdkMediaCodec` OutputBuffer 硬解
- [x] 2.3 实现硬解/软解输出统一 NV12 归一化 + NV12→BGR/RGB 转换（libyuv / OpenCV）
- [x] 2.4 实现 Java 控制面 JNI：`startStreamDetect` / `stopStreamDetect`、`setLaserOn`、基础 session 参数
- [x] 2.5 实现 native 500ms 抽帧调度器骨架（可先 stub 检测，仅验证取帧与色彩转换）
- [x] 2.6 焊接路径：激光 ON/OFF 时启停 C++ 管线，替代 `LivePr1InferenceStreamClient` 检测解码（feature flag 可回退）
- [x] 2.7 验证 PR0 录制与 `EasyPlayerClientManger` 不受 C++ PR1 检测会话影响
- [ ] 2.8 验收：C++ 稳定拉 `rtsp://127.0.0.1:8554/camera/pr1`、硬解取帧、NV12→BGR 正确，MediaMTX 多读者正常（见 [`notes/stream-detect-pipeline-acceptance.md`](notes/stream-detect-pipeline-acceptance.md)）

## 3. Phase 2 — 检测算法、Pub-Sub 与 Coordinator 改造

- [x] 3.1 实现 JNI 单一上行事件桥（`detect_result`、`pipeline_state`、`session_start|stop`、`error`）
- [x] 3.2 实现 Java `StreamDetectResultBus` + latest-result cache + 线程分发策略
- [x] 3.3 C++ 管线内接通 OpenCV lens_det（`analyzeBgr` / stain session），进程内检测无 JNI 传图
- [x] 3.4 C++ 管线内接通 zero_point（machine-model 路由）与 edgedrawing 检测模块
- [x] 3.5 实现 RKNN 流式路径：BGR/RGB 就绪后按产品开关调用 native RKNN streaming 入口，结果同 bus 发布
- [x] 3.6 实现 native burst 调度（code=-5 → 100ms）及 laser OFF 重置，对齐 `laser-detect-frame-rejected-burst`
- [x] 3.7 改造 `OpencvStainDetectCoordinator` 为 Subscriber（告警、L001、Modbus 编排），移除 live PR1 `opencvStainDetectFromI420`
- [x] 3.8 改造 `ZeroPointManualAutoCoordinator` / 激光零点路径为 Subscriber，移除 live PR1 I420 JNI 调用
- [x] 3.9 改造 `CameraAiHttpPublisher` 订阅 bus 驱动 SSE `start`/`running`/`stop`/`error`
- [x] 3.10 改造 `DetectionOverlayView` / AI Vision overlay 订阅 bus，按 `timestampMs`/`frame_id` 渲染
- [x] 3.11 实现控制面 JNI 扩展：`setBurstMode`、模块 enable、ROI 路径、`cameraType` 配置
- [x] 3.12 删除或废弃焊接路径 live PR1 Java 解码检测代码（`LivePr1InferenceStreamClient` 检测用途、`LatestI420FrameHolder` live 路径）
- [x] 3.13 单元/仪器测试：native 色彩转换、bus 分发、Coordinator 映射 `AiStainDetectResult`；焊接场景端到端冒烟

## 4. Phase 3 — AI Vision 双链路验收

- [x] 4.1 AI Vision：`EasyPlayerClient` 硬解播放 PR1 与 C++ `StreamDetectPipeline` 并行启动（独立 RTSP 会话）
- [x] 4.2 移除 AI Vision live 剩余 Java I420/bitmap 检测路径，overlay 完全依赖 bus
- [x] 4.3 RK3566 压测 checklist：双路 1080p 硬解 CPU/内存/温升、UI 流畅度、overlay 100–300ms 同步容忍
- [x] 4.4 压测不通过时实现产品过渡策略（保留 Java 播放，检测回退或隐藏 overlay，焊接仍 C++ 单链路）
- [x] 4.5 更新 `ai-vision-live-resolution-profile` 相关日志与 field test 记录

## 5. Phase 4 — 稳定性、可观测性与文档

- [x] 5.1 实现 RTSP 断流检测、bounded reconnect backoff、Java lifecycle 联动释放
- [x] 5.2 检测结果 stale 超时（overlay「检测中」/隐藏）、`frame_id` 单调递增与日志关联
- [x] 5.3 性能统计埋点：decode ms、detect ms、端到端 ms、reconnect 次数；可观测性日志区分 playback vs detect pipeline
- [x] 5.4 C++ 异常时 UI「检测中断」文案与 SSE `error`/`stop` 上报，播放不受影响
- [x] 5.5 更新 `OPENCV_DETECT_APP_INTEGRATION.md`、Native API 文档、六层 checklist
- [x] 5.6 归档 OpenSpec delta specs 到 `openspec/specs/`（见下方 5.6b）
- [x] 5.6b 移除 feature flag 与废弃类（焊接 native 常开；删除 `LivePr1InferenceStreamClient` / Hub / `LatestI420FrameHolder`；AI Vision 仍保留 `isNativeAiVisionStreamDetectEnabled` 4.4 flag）
- [x] 5.7 确认离线 MP4（ExoPlayer + `opencvStainDetectFromI420` 500ms 网格）路径回归无回归（见 [`notes/offline-mp4-regression.md`](notes/offline-mp4-regression.md)）

## 6. 验证与发布

- [ ] 6.1 Emulator / RK3566 焊接场景全流程：激光 ON/OFF、burst、脏污告警、零点检测、SSE 订阅（见 [`notes/e2e-signoff-checklist.md`](notes/e2e-signoff-checklist.md)）
- [ ] 6.2 AI Vision 双链路场景全流程（若 Phase 3 通过）
- [x] 6.3 Code review：无 live RTSP 路径残留 `nativeOpencv*FromI420` / `getBitmap` 喂检测（见 [`notes/live-detect-path-audit.md`](notes/live-detect-path-audit.md)）
- [ ] 6.4 `make sync` 实机/模拟器验收并记录 sign-off
