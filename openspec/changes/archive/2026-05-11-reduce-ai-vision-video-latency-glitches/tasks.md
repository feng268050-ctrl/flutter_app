## 0. Root cause investigation (必须先于参数/架构大改)

- [x] 0.0 **代码栈根因摘录**（离线）：`openspec/changes/reduce-ai-vision-video-latency-glitches/notes/rca-ip-camera-latency.md`；App 首帧 `RESULT_VIDEO_DISPLAYED` 日志含 `decodeType`（0=fallback+PTS 调速，1=MediaCodec）。
- [x] 0.1 建立最小复现：**同一网络、同一 RTSP URL** 下对比 VLC 与 AI Vision；记录是否「仅 App 差」或「两处都差」（指向网络/IPC vs 端侧解码/UI）。
- [x] 0.2 二分：`ENABLE_LENS_GUARD_STARTUP` 关闭与开启各跑一次，观察花屏/延迟是否显著相关（CPU 争用排查）。
- [x] 0.3 核对网络事实：`ip addr`/`ifconfig` 确认 `eth0`、本机 IP、与 IPC 是否同 /24；必要时 ping / 短日志记录配网命令返回值。
- [x] 0.4 产出 **一页内根因结论**：归类为 {网络, RTSP/编码, 播放器缓冲, CPU/线程, 待定} 之一，并附上证据索引；未归类为「待定」前，不启动 §3 的低延迟实现项（3.2 及以后可依赖 0.4 结论选择性执行）。

## 1. Baseline & measurement

- [x] 1.1 Record current baseline: VLC vs AI Vision subjective delay under same LAN; note RTSP URL, resolution, codec, and `ENABLE_LENS_GUARD_STARTUP` state.
- [x] 1.2 Add concise log markers in `AiVisionFragment` / player start path: resolved RTSP URL, transport mode, reconnect attempt counter, timestamps for first decoded frame hint (if callbacks available).

## 2. Network layer (对齐 `实时视频流.md`)

- [x] 2.1 Confirm Ethernet setup (`prepareNetworkAndStartStream` / `setCameraNetworkSegment`) runs reliably before playback; document tablet IP/subnet assumptions vs IPC default IP conflicts.
- [x] 2.2 Extend diagnostics: optional ping or HEAD to camera HTTP admin (where permitted) guarded by timeout; log failures without blocking playback forever.

## 3. Decoder / player tuning (EasyPlayer / EasyRTSP)

- [x] 3.1 Audit `library/.../EasyPlayerClient.java` and JNI for buffer size, RTSP OPTIONS, RTP reorder, or `max_delay` equivalents; document which knobs exist.
- [x] 3.2 Implement **low-latency profile**: reduce receive/decode buffering where APIs exist; gate behind debug flag or remote config defaulting to conservative if risky.
- [x] 3.3 Define recovery policy on `RESULT_TIMEOUT`, `RESULT_UNSUPPORTED_VIDEO`, decode error events: `stop()` + bounded `startStream()` backoff; avoid benign RTSP CONNECTING events as failures (preserve existing guard).

## 4. Rendering path

- [x] 4.1 Evaluate `TextureView` vs `SurfaceView` trade-off for RK3566; if keeping TextureView, document vs doc’s SurfaceView recommendation and any matrix/zoom repaint cost.

## 5. Inference interaction (latency / glitch correlation)

- [x] 5.1 Profile `LensGuardManager.onI420Frame` copy path under load; if needed add bounded queue or decimate frames when backlog exceeds threshold (logged).
- [x] 5.2 Ensure AI path cannot block decoding thread — offload heavy work to dedicated executor already used by native layer if applicable.

## 6. Verification & rollout

- [x] 6.1 Field checklist: ethernet `eth0` up, subnet match, RTP/TCP playable in VLC, then AI Vision first-frame < target (document measured value).
- [x] 6.2 Stress: unplug/replug cable, bitrate spike scenario; observe recovery ≤ N seconds without permanent corruption.
- [x] 6.3 Decide phase-2 spike: FFmpeg TCP + `-fflags nobuffer` POC or MPP direct decode feasibility study (no code obligation in phase 1).
