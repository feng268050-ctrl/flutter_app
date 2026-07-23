# RK3566 + IPC 双码流（摘要）

> 原文：[`../双码流.md`](../双码流.md)  
> 以太网拓扑：[`camera-eth0-topology.md`](camera-eth0-topology.md)

## 一句话

**主流 PR0** 负责录制，**子流 PR1** 负责实时预览与推理，减轻单路高码流压力；当前 IPC 主/子均为 **1920×1080**，AI Vision 页 **默认不拉 RTSP**。

## 分工

| 码流 | RTSP 路径 | 用途 |
|------|-----------|------|
| 主流 | `/PR0` | 录制（`RECORDING_RTSP_URL`） |
| 子流 | `/PR1` | 实时预览 + 推理（`LIVE_INFERENCE_RTSP_URL`） |

子流编码建议：H.264 Baseline、CBR、短 GOP、无 B 帧。

## 代码对应

| 能力 | 位置 |
|------|------|
| URL 常量 | `CameraConfig` |
| 录制走主流 | `EasyPlayerClientManger`、`BackgroundLoopRecorder` |
| 实时先子后主 | `AiVisionFragment.ensureLiveRtspCandidates()` |
| 探测脚本 | `scripts/device-network/probe-dual-stream.sh` |

## 产品态（重要）

`AiVisionFragment.LIVE_RTSP_PULL_ENABLED = false` — AI Vision 页当前为 **工艺库视频本地回放**（ExoPlayer），非摄像头子流。

- 后台录制（PR0）仍可用
- 实时子流 + 叠框代码保留但默认关闭；改 `true` 需现场回归
- 镜片 I420 推帧可能仍来自录制主流路径

## 模型输入

App 推全帧 I420；ROI（700×700 → 640）由 **native 层**处理，与 RTSP 分辨率解耦。产线建议 **1920×1080**。

## 可完成度（2026-05）

| 维度 | 状态 |
|------|------|
| 配置与录制分流 | 已落地 |
| AI Vision 实时双码流 | 代码具备、产品默认关闭 |
| 子流降分辨率 | 待 IPC 固件 |
| 30min+ 并行稳定性 | 待回归 |

## 验证清单

1. `probe-dual-stream.sh` → PR0/PR1 均 `DESCRIBE 200 OK`
2. logcat `RECORD_RTSP` 含 `/PR0`
3. 启用拉流时 `LIVE_VIDEO_SIZE` 含 `/PR1`；失败回退 `/PR0`
4. 双路 1080p 并行看 CPU、掉帧、花屏
5. 关闭拉流时确认页面为工艺视频回放

## 延伸阅读

- [`dual-stream-workflow.md`](dual-stream-workflow.md) — 分阶段 checklist
- [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) §8 — 推帧格式
