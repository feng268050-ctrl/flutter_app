# RCA: AI Vision 摄像头延迟偏大（当前物理设备）

## 结论

当前证据更支持根因归类为：**播放器缓冲 / 解码消费跟不上**，并且 **AI 帧处理可能加重 CPU/内存带宽争用**。网络同网段与 ICMP 连通性本次未显示异常。

## 证据

- 物理设备：`54b515de0f9d06f1`
- 设备网络：
  - `eth0` up，`192.168.1.234/24`
  - 路由存在：`192.168.1.0/24 dev eth0 src 192.168.1.234`
  - 摄像头默认 IP：`192.168.1.100`
- Ping 摄像头：
  - `3 packets transmitted, 3 received, 0% packet loss`
  - RTT `min/avg/max = 0.741/0.766/0.792 ms`
- AI Vision / EasyPlayer 日志：
  - 持续出现 `queue full:500`
  - `cache` 约 `34–35s`
  - 出现 `sleep time.too long`，说明消费侧明显落后于生产侧
  - 同时间段 `LensGuardManager` 持续输出检测结果，说明 AI 路径处于运行状态，可能与视频解码争用资源

## 待补证据

- VLC 与 AI Vision 的同 URL 视觉延迟对比还未由现场明确记录；历史信息仅确认 VLC 可播放 `rtsp://192.168.1.100/PR0`。
- 新版 App 需要部署后查看 `VIDEO_DISPLAYED decodeType=... firstFrameMs=...`，确认当前是 MediaCodec 硬解（1）还是 fallback/lite + PTS pacing（0）。

## 下一步

1. 先部署含首帧日志的版本，确认 `decodeType`。
2. 若 `decodeType=0`，优先修硬解路径或分辨率/格式兼容问题。
3. 若 `decodeType=1` 仍出现 `queue full:500` 和几十秒 cache，优先限制帧队列深度、丢弃过旧帧，保证实时性。
4. 用 `ENABLE_LENS_GUARD_STARTUP=false` 对比一次，确认 AI 帧处理对队列积压的贡献。

## 播放器可调项审计

- `EasyPlayerClient.start(url, type, sendOption, mediaType, user, pwd)` 会继续调用 `Client.openStream(...)`。
- `Client.openStream()` 当前 JNI 参数为：
  - `type`: `TRANSTYPE_TCP` / `TRANSTYPE_UDP`
  - `reconn`: 固定 `1000`
  - `outRtpPacket`: 固定 `0`
  - `rtspOption`: 透传 `sendOption`
- Java 层未暴露 `max_delay`、RTP reorder buffer 或解码缓存大小等命名配置。
- 当前明确可控的应用层延迟来源是 `EasyPlayerClient.FrameInfoQueue`：默认最多 500 帧，现场已经观察到 `queue full:500`。

## 本期修复方向

在不改 JNI/播放器 native 库的前提下，优先为 **AI Vision 播放实例**开启低延迟队列策略：队列超过小阈值时丢弃旧视频帧，保留最新帧，避免端到端延迟滚到几十秒。

## 已落地策略

- `AiVisionFragment` 对自己的 `EasyPlayerClient` 调用 `setLowLatencyMode(true)`；录制等其它播放器实例默认不启用。
- `EasyPlayerClient.FrameInfoQueue` 在低延迟模式下将视频帧队列限制在小阈值（6），超限时丢弃旧帧并记录 `low latency drop stale frames`。
- AI Vision 对 `LensGuardManager.onI420Frame` 输入做 200ms 最小间隔（约 5fps）限频；跳过帧会周期性记录 `AI frame decimation skipped=...`，优先保护视频解码实时性。
- 既有恢复策略保持：`RESULT_TIMEOUT` / `RESULT_UNSUPPORTED_VIDEO` 进入 `onStreamFailed()`，最多重试 `MAX_RETRY_COUNT` 次；`Connecting...` 等 benign RTSP event 不触发失败。
