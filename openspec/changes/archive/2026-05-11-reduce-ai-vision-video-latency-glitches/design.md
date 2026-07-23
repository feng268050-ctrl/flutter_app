## Context

AI Vision 通过 `AiVisionFragment` 使用 EasyDarwin `EasyPlayerClient` 播放 `CameraConfig.rtspUrl()`（默认 `rtsp://<host>/PR0`，TCP transport），画面落在 `TextureView`。`LensGuardManager` 在引擎运行时可订阅同一解码路径的 I420 回调。

`实时视频流.md` 强调：IPC 与 RK3566 同网段、RTSP TCP 稳定性、nobuffer/low_delay/framedrop 类策略、MPP 硬解与渲染线程分层。当前产品栈仍为 Java + EasyRTSP/JNI，**不假设**一步到位替换为 FFmpeg→MPP→SurfaceView；第一期在现有栈内做可观测、可调参、低风险优化。

## Goals / Non-Goals

**Goals:**

- 在**当前播放器栈**上降低体感延迟（首帧与会话稳态），并降低可复现的花屏频次或缩短恢复时间。
- 对齐文档的网络前置条件：播放前以太网与同网段配置可验证、日志可追踪。
- 为后续「FFmpeg/GStreamer + MPP + SurfaceView/OES」留好接口边界（配置项、能力开关），但不作为本期必交付。

**Non-Goals:**

- 本期不强制替换为全新解码管线或引入大型 native 依赖（除非评估后明确纳入二期）。
- 不改变摄像头侧编码协议（H.264/H.265）的产品签约，除非与厂商联调另开变更。

## Decisions

0. **先排查根因，再改实现**  
   - *Rationale*：延迟与花屏可能来自 L2/L3（不同网段、`eth0` 未起）、RTSP 服务端（错误 path/鉴权）、RTP 丢包、解码器参考帧损坏、或 CPU 被 AI/主线程拖住。无证据调参会误判。  
   - *Process*：最小复现 → 对照 VLC 同 URL → 二分（关 `LensGuard` / 关教学层 / 有线单设备）→ 记录 logcat 与时间线 → 归类后再动代码。  
   - *Exit*：形成简短《根因结论》文档或 change 内 notes（1 页内），再进入缓冲/重连等实现任务。

1. **Transport：默认保持 TCP**  
   - *Rationale*：与文档及当前 `Client.TRANSTYPE_TCP` 一致，弱网下减少花屏与断流。  
   - *Alternative*：UDP 更低延迟但丢包风险更高；仅作为调试开关或二期 A/B。

2. **缓冲与低延迟：先「可配置 + 可观测」**  
   - *Rationale*：EasyPlayer/EasyRTSP 层可暴露的 buffer 参数需查 JNI；在能改动的层级设置低延迟偏好（含已有 `waiting_i_frame` 等）。  
   - *Alternative*：直接切 FFmpeg `-fflags nobuffer`；工作量大，列二期。

3. **花屏恢复：分层处理**  
   - *Rationale*：浅层为应用层 `stop`→`start` 与重试退避；深层为解码器关键帧策略（尽量在配置层请求 IDR / 跳帧策略）。  
   - *Alternative*：无限重试导致 UI 卡死；须上限与用户可见状态。

4. **AI 帧消费与视频竞争**  
   - *Rationale*：`onI420Frame` 全量拷贝已存在；若 CPU 紧张，增加抽帧或后台队列深度上限，避免阻塞解码回调线程。  
   - *Alternative*：关闭 `ENABLE_LENS_GUARD_STARTUP` 时仅播放无 AI；行为保持产品可配置。

5. **新设备**  
   - *Rationale*：RTSP host、路径、账号仍可能变化；继续用偏好覆盖 host，路径/端口后续可扩展为完整 URL 或独立字段，避免拼错。

## Risks / Trade-offs

- **[Risk] 底层库参数不可调或调了无效** → *Mitigation*：先加日志与基准（首帧时间、重连次数）；再评估 JNI 层 patch 或换栈。  
- **[Risk] 过度降低缓冲导致卡顿或花屏增加** → *Mitigation*：参数产品化分级（低延迟 / 平衡）。  
- **[Risk] 抽帧影响 AI 灵敏度** → *Mitigation*：抽帧仅在高负载或配置开启时启用，并记录指标。  
- **[Risk] eth0 配置需要 root/YNH** → *Mitigation*：失败时明确日志与 UI 提示，不静默失败。

## Migration Plan

1. 灰度构建：默认行为与现网一致，低延迟相关项以 **debug/工程开关** 或构建属性开启。  
2. 现场对照：同网络下 VLC 与 App 并列测延迟与花屏。  
3. 若指标回退，关闭开关即回滚，无需数据迁移。

## Open Questions

- 单次现场问题属于哪一类根因（网络 / 服务端 / 播放器 / CPU 争用）？须在 `tasks.md` 第 0 节勾选完成后再关闭。  
- EasyPlayerClient 是否暴露 RTSP 接收/解码缓冲、max_delay 等 JNI 配置？需读 `library` 源码或厂商文档。  
- 花屏主因是 **网络丢包** 还是 **解码线程饥饿**？需现场抓一次 logcat + 简单 CPU 采样。  
- 摄像头是否支持 **子流/低分辨率** URL，用于优先低延迟子画面？
