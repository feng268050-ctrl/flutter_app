# 双码流实施流程（执行版）

## 阶段 1：能力确认（已完成）

- [x] 1.1 设备网络可达：`eth0` 在 `192.168.1.0/24`，摄像头 `ping` 0% 丢包
- [x] 1.2 RTSP 路径探测：`PR0/PR1` 均 `DESCRIBE 200 OK`
- [x] 1.3 固化脚本：`scripts/device-network/probe-dual-stream.sh`

运行命令：

```bash
scripts/device-network/probe-dual-stream.sh <adb_serial> 192.168.1.100
```

## 阶段 2：摄像头参数固化（IPC Web）

**现状（当前摄像头限制）**：主码流与子码流分辨率均被固化为 **`1920×1080`**，双码流仅区分 **RTSP 通道（`PR0` / `PR1`）** 与编码参数，**不能**靠子码流降低像素量。

在 **视觉音频参数** 里：渠道选 **Infrared**，**主子代码** 分别配置 **Main / Sub**，子流建议仍用 **H.264 Baseline、CBR、固定帧率、较短 I 帧间隔**，在相同分辨率下尽量降低延迟与花屏（码率可按 IPC 能力上调）。

| 项 | 主码流 (Main) | 子码流 (Sub) |
|----|---------------|--------------|
| 分辨率 | **1920×1080** | **1920×1080**（与主路一致） |
| 用途 | 录制 | 实时预览 + 推理 |

- [ ] 2.1 IPC：主码流 `1920×1080`（录制）
- [ ] 2.2 IPC：子码流 `1920×1080`（实时预览 + 推理）
- [ ] 2.3 确认子码流 **无 B 帧**（若界面有独立开关则关闭；Baseline 通常无 B 帧）

## 阶段 3：App 行为验证（现场 logcat）

代码路径：`AiVisionFragment` 先试子流再试主流（`LIVE_INFERENCE_RTSP_URL` → `CAMERA_RTSP_MAIN_URL`）；`EasyPlayerClientManger` / `BackgroundLoopRecorder` 录制走 `RECORDING_RTSP_URL`（`PR0`）。

现场抓取标签：`AiVisionFragment`、`EasyPlayerClientManger`、`BackgroundLoopRecorder`。

- [ ] 3.1 AI Vision 首次拉流：`RTSP start request ... profile=sub candidate=1/2`，URL 含配置的子流路径（默认 `/PR1`）
- [ ] 3.2 若子流失败：先有 `Switching live RTSP candidate...`，随后 `profile=main candidate=2/2`
- [ ] 3.3 开始录制：`RECORD_RTSP start url=... profile=main`（或后台循环 `RECORD_RTSP loop ...`），URL 含主流路径（默认 `/PR0`）

主/子 RTSP 路径固定为 `CameraConfig.CAMERA_RTSP_MAIN_PATH`（`/PR0`）、`CAMERA_RTSP_SUB_PATH`（`/PR1`），与 IPC 硬件契约一致，**不可**在 App 内覆盖。

## 阶段 4：分辨率验收（待现场）

- [ ] 4.1 实时链路：`LIVE_VIDEO_SIZE` / `RESULT_VIDEO_SIZE` 与 IPC 子码流一致，目标 **`1920x1080`**（或解码上报 **`1920x1088`** 等编码对齐高度，以日志为准）
- [ ] 4.2 录制文件元数据/播放确认 **`1920x1080`**（主流）
- [ ] 4.3 双路均为 1080p 时重点验 **并行稳定**、断流重连与花屏恢复（对照单路）

## 阶段 5：回归与放量

- [ ] 5.1 运行 30 分钟稳定性（断流重连、不卡死）
- [ ] 5.2 对比 `DISABLE_LENS_GUARD` 开/关的平滑性
- [ ] 5.3 达标后将双码流策略作为默认配置放量

