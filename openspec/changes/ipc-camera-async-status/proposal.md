## Why

量产拓扑下 eth0 专链直连 IPC，但相机上电往往晚于 HMI 首屏；开机自检里的 Camera Comm 几乎必失败。需要首屏后异步把链路拉起、事件驱动重连，并用状态栏表达连接中 / 已通 / 失败。要预览/多消费者拉流，本产品还需 **MediaMTX**。同时：HAL 的 **`ip_camera` 必须是可复用的「IP 网络相机设备」抽象**，不得把「主板直连 eth0」写进通用语义——那是当前产品拓扑，未来产品可能换连法。

## What Changes

- 在 **`cyber_hal` 新增独立域 `ip_camera`**（`package:cyber_hal/ip_camera.dart`）：只描述 IP 相机设备本身（主机、上游 RTSP 端点、健康/重连观察）。**不**包含 eth0 专链、地址规划、MediaMTX。
- **本产品拓扑与编排留在 App**（`features/ip_camera` 或等价 coordinator）：dedicated eth0 配址、订 `Ethernet`/`Wifi` D-Bus 事件触发重配、尝试预算 → UI `connecting|connected|failed`、按需启动 MediaMTX、把「本地预览 URL」交给 Settings。
- **MediaMTX**：overlay 实装 render + on-demand unit；编排在 **产品 coordinator**（可薄封装 `systemctl`），upstream 来自 `IpCamera` 的原生流地址。
- **GStreamer/MPP 实时预览（本变更必交付）**：启用 Buildroot GStreamer RTSP + Rockchip MPP；默认 Weston 镜像的 flutter-embedded-linux client 链接 Sony eLinux GStreamer `video_player` plugin，备选 flutter-pi 镜像内建其 GStreamer video plugin。App 使用 Flutter `video_player` 兼容 API 把 `rtsp://127.0.0.1:8554/camera/pr1` 渲染成真实视频纹理。占位 UI 只允许用于 establishing / failed / 首帧等待，**不得**把“显示 URL / GStreamer pending”当作预览完成。
- **HAL 录像能力**：`ip_camera` 同时抽象单路 RTSP 录像状态机和落盘结果；`startRecording` 在 GStreamer muxer 收到首个可写媒体数据前保持 preparing，超时/候选流失败由 HAL 自己重试或闭环失败，不能由 UI 猜测“已开始”。`stopRecording` 必须发送 EOS、完成 MP4 封装并返回最终文件路径。
- 事件驱动：链路/Wi‑Fi 用现有 network Streams（回调）；ICMP 健康在 **`ip_camera` HAL 内**有界轮询；产品层把 path-ready + health 折叠成状态栏状态。
- 开机自检去掉 Camera Comm；Home 右上角状态图标；Common Settings 去掉 Ethernet；**Input → IP Camera** 预览（经本产品 MediaMTX 本地 URL）并在预览下提供仅用于设置页演示的“Record / Stop”按钮。演示录像写入 `/userdata/storage/Videos/movie/<yyyy-MM-dd>/<yy-MM-dd_HH-mm-ss>.mp4`，停止后只提示路径，不接入快速模式/工程师模式业务录像或文件管理。

## Capabilities

### New Capabilities

- `ip-camera`: 可移植的 IP 网络相机 HAL（主机、上游流、健康 Stream、等待流就绪的录像控制与文件结果）；产品侧专链/MediaMTX/状态栏/预览的编排与 UI 契约。

### Modified Capabilities

- `dart-hal`: 增加独立模块 `ip_camera`（网络依赖的输入场景；USB/串口摄像头若出现则归 `input`）；BoardBindings 可构造；stub 可测。
- `product-boot-self-check`: 去掉 Camera Comm。
- `product-home-ui`: Home 右上角相机链路状态图标（订产品 session，非把拓扑写进 HAL）。
- `settings-ui`: Network 去 Ethernet；Input 增加 IP Camera 预览页。
- `buildroot-lws-hmi-image`: 产品镜像启用 GStreamer RTSP、Rockchip MPP 硬解与两套 embedder 的视频插件（默认 Weston/eLinux，备选 flutter-pi），满足 IP Camera 本地 relay 实时预览。

## Impact

- HAL：`ip_camera` 模块（portable）。
- App：产品 `IpCameraSession`/coordinator（eth0 + MediaMTX + UI 状态）；Home / Settings。
- App 视频：接入真实 Flutter 视频控制器/纹理，管理页面进入、退出、错误与重连生命周期。
- Overlay：真实 `render-mediamtx-config.sh`、`mediamtx.service`；eth0 专链经 **Ethernet HAL**（非独立 configure 脚本）。
- Rootfs/runtime：GStreamer RTSP/RTP、H.264/H.265 parser、MP4 mux、Rockchip MPP 硬解，以及 flutter-pi 与 Weston/flutter-embedded-linux 两套 embedder 的 GStreamer video player plugin；需分别验证持续运动画面与录像文件可播放。
- 对照：lws-ui 拓扑与 PingHealth / MediaMTX；HAL 边界对齐 `docs/hal-portability.md`。
