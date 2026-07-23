# LAN 摄像头流与 AI Vision 集成说明

本文说明 **MediaMTX PR0 中继**、**`GET /v1/camera/ai`** 与 **AI Vision Tab** 的分工及现场验收。

## 三条管线（目的不同）

| 管线 | 源 | 输出 | 典型消费者 |
|------|-----|------|------------|
| `rtsp://<device-ip>:8554/camera/pr0` | PR0（MediaMTX 单路上游） | RTSP fan-out | LAN 监控、ffplay/VLC |
| `/v1/camera/ai` | PR1 推理采样 | SSE JSON | 远程叠加数据 |
| AI Vision Tab | PR1（失败回退 PR0） | 屏上 TextureView + overlay | 操作员本机 |
| 快速/工程师录像 | PR0 经 `rtsp://127.0.0.1:8554/camera/pr0` | 本地 MP4 | `EasyPlayerClientManger` |

**已移除** `GET /v1/camera/live`（HTTP 裸流）。LAN 视频 MUST 使用 RTSP 中继 URL。

## MediaMTX 与录制

- 仅 MediaMTX 直连 `CameraConfig.RECORDING_RTSP_URL`（摄像头 `/PR0`）。
- HMI 录像、`POST /v1/camera/record` 与 LAN 观众均为 `camera/pr0` 的读者。
- 构建：`make mediamtx`；OTA 可选 `mediamtx_v*` 制品（见 `tools/mediamtx/README.md`）。

## `/v1/camera/ai` 行为摘要

SSE 推送 `inference` 事件，**不含**视频字节。画面使用 **`rtsp://<device-lan-ip>:8554/camera/pr0`** 单独播放并在客户端按时间戳绘制 overlay。

## 现场验收 checklist

1. `ffplay -rtsp_transport udp rtsp://<device-ip>:8554/camera/pr0` 可连续播放。
2. `curl -N http://<device-ip>:5580/v1/camera/ai` 收到 `inference` / `heartbeat`。（`:8080` 已废弃）
3. 快速模式开始录像时 logcat `RECORD_RTSP` 的 url 为 `rtsp://127.0.0.1:8554/camera/pr0`。
4. 录像 + ffplay 同时进行时，摄像头仅一条 PR0 上游（MediaMTX）。
